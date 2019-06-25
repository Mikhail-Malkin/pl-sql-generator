declare 

    -- сами данные     
    json_data varchar2(32000) := '[{
        "package":"msgp",
        "prefix":"MSG",
        "schema":"devuser",
        "grants":["CRM","GENERAL","ISSA"],
        "synonyms":["CRM","GENERAL","ISSA"],
        "servicePackage":"",
        "tables":[{
            "servicePackage":"",
            "name":"devuser.messages",
            "mapper":"",
            "shortname":"msg",
            "primaykey":"id",
            "sequence":"",
            "defaultfuncs":[
                {"type":"findById"},
                {"type":"existsById"},
                {"type":"add","name":"","servicePackage":"","options":""},
                {"type":"update"},
                {"type":"delete"},
                {"type":"findByUnique"},
                {"type":"findAllByFk"},
                {"type":"findFirstByFK"},
                {"type":"existsByUnique"},
                {"type":"existsByFK"}]}]}]';
    
    -- type tList is table of varchar2(32000); 
    cBody       constant number := 1;
    cSpec       constant number := 2;
    cScript     constant number := 3;
    cConst      constant number := 4;
    cProcSpec   constant number := 5;
    cProcBody   constant number := 6;
    
    nl constant varchar2(1) := chr(10);
    -- переменные 
    vGrants     tList;  -- гранты 
    vSyno       tList;  -- синонимы 
    vTabs       tList;  -- таблицы 
    vCustFuncs  tList;  -- кастомные функции 
    
    vPrimKeyName     varchar2(200);
    vPrimKeyType     varchar2(200);
    vSeqName         varchar2(200);

    type tListInd is table of varchar2(200) index by varchar2(200);
    vFuncNames           tListInd;
    cFunc_add            constant varchar2(200) := 'add';
    cFunc_update         constant varchar2(200) := 'update';
    cFunc_delete         constant varchar2(200) := 'delete';
    cFunc_findById       constant varchar2(200) := 'findById';
    cFunc_findByUnique   constant varchar2(200) := 'findByUnique';
    cFunc_findAllByFk    constant varchar2(200) := 'findAllByFk';
    cFunc_findFirstByFK  constant varchar2(200) := 'findFirstByFK';
    cFunc_existsById     constant varchar2(200) := 'existsById';
    cFunc_existsByUnique constant varchar2(200) := 'existsByUnique';
    cFunc_existsByFK     constant varchar2(200) := 'existsByFK';
    
    vDefFuncName_Get varchar2(200);
    vDefFuncName_Add varchar2(200);
    
    -- колонки и таблицы 
    type tTabCols       is table of all_tab_columns%rowtype index by varchar2(2000);
    type tTabColsNum    is table of all_tab_columns%rowtype index by binary_integer;
    
    type tTabComments   is table of varchar2(200) index by varchar2(200);
    vTabCols        tTabCols;       -- список столбцев с которыми и будет производиться работа пока 
    vTabColsNum     tTabColsNum;    -- список столбцев с которыми и будет производиться работа пока 
    vTempTabCols    tList;          -- временный массив полей с которыми надо будет работать при автогенерации множества процедур
    vTabComments    tTabComments;   -- список комментов в полям таблицы 
    vOptions        tList;          -- временный список опций для функций 
    vOwner          varchar2(200);  
    vTable          varchar2(200);  
    f               boolean;
    vComment        varchar2(2000);
    vTableCaption   varchar2(2000);
    vErrNum         number;
    -- 
    ind          number;
    type tClob is table of clob index by binary_integer;
    vClobs tClob; 
    
    vStrTemp        varchar2(32000);
    vFuncNameTemp   varchar2(200);
    vInd            varchar2(200);
    
    -- разбираем строку по составлюящим - вернее возьмём всё что нам надо из переданной строки 
    function getLeks(pStr varchar2, ind number, delim varchar2 := '.') return varchar2 is
        pos number; 
        posEnd number; 
    begin
        posEnd := instr(pStr, delim, 1, ind);
        if posEnd = 0 then 
            posEnd := length(pStr) + 1;
        end if; 
        if ind = 1 then 
            pos := 1;
        else 
            pos := instr(pStr, delim, 1, ind - 1) + length(delim);    
        end if; 
        
        return substr(pStr, pos, posEnd - pos);
    end; 

    -- Поиск коммента таблицы 
    function getTableCaption(pOwner varchar2, pTable varchar2) return varchar2 is 
        vName varchar2(2000); 
    begin 
        select comments into vName from all_tab_comments 
        where table_name = upper(pTable) and owner = upper(pOwner);
        return getLeks(vName, 1, '|');
    exception 
        when no_data_found then  
            return pTable; 
    end;
    
    -- Поиск коммента колонки 
    function getFieldCaption(pOwner varchar2, pTable varchar2, pCol varchar2) return varchar2  is 
        vName varchar2(2000); 
    begin 
        select comments into vName from all_col_comments 
        where table_name = upper(pTable) and owner = upper(pOwner) and column_name = upper(pCol);
        return getLeks(vName, 1, '|');
    exception 
        when no_data_found then  
            return pCol; 
    end;

    -- функция разбора и заполнения данными простого массива 
    procedure fillList(pList in out nocopy tList, pClob clob, pJson boolean := false) is 
    begin
        pList := tList(); -- занулим данные (вроде можно использовать null - надо проверитьс использованием select bulk collect into)
        if not pJson then
            select f1 bulk collect into pList from json_table(pClob, '$[*]' columns f1 varchar2(200) path '$[*]');
        else 
            select f1 bulk collect into pList from json_table(pClob, '$[*]' columns f1 clob format json path '$[*]');
        end if;
    end;
    
    function existsList(pList in out nocopy tList, pValue varchar2) return boolean is 
    begin
        if pList.Count = 0 then 
            return false; 
        end if; 
        for i in pList.first..pList.last loop 
            if upper(pList(i)) = upper(pValue) then 
              return true;
            end if;
        end loop; 
        return false; 
    end;
    
    -- распечатаем то что там у нас получилось
    procedure printList(pList in out nocopy tList) is
        vI number; 
    begin
        dbms_output.put_line('----------------------');
        vI := pList.first;
        while vI is not null loop
            dbms_output.put_line(pList(vI));
            vI := pList.next(vI);
        end loop; 
    end;
    
    -- добавление строки в определённый CLOB 
    procedure addCode(pType number, pCode clob, pParams tList := null, pLevel number := 1) is 
        vStr varchar2(32000) := lpad(' ', 2 * pLevel, ' ') || pCode  || chr(10); 
        ind number;
    begin
        -- подставим значени в плейсхолдеры 
        if pParams is not null then 
            ind := pParams.last; 
            while ind is not null loop
                vStr := replace(vStr, '%' || to_char(ind), pParams(ind));
                ind := pParams.prior(ind);
            end loop; 
        end if;
        vStr := replace(vStr, '$\', '%');
        -- создадим новый клоб если сие необходимо 
        if not vClobs.exists(pType) then 
            vClobs(pType) := vStr;
        else    
            -- или же добавим новую строку в клоб
            dbms_lob.append(vClobs(pType), vStr);
        end if;
    end; 
    
    -- если надо для двух разных клобов добавить одно и тоже - то сделаем это для каждого клоба по одному разу
    procedure addSequence(pSeqName varchar2) is 
        vCount number; 
    begin
        if dbms_lob.instr(vClobs(cScript), 'create sequence ' || upper(pSeqName) || ' start') = 0 then 
            select count(*) into vCount from all_sequences where sequence_name = upper(pSeqName);
            if vCount = 0 then 
                addCode(cScript, 'create sequence %1 start with 1 increment by 1;', tList(upper(pSeqName)), 0);
            end if;
        end if;
    end;
    
    procedure addCode2(pType1 number, pType2 number, pCode clob, pParams tList := null, pLevel number := 1) is 
    begin
        addCode(pType1, pCode, pParams, pLevel);
        addCode(pType2, pCode, pParams, pLevel);
    end; 
    
    -- после того как всё получилось - почистим созданные клобы 
    procedure clearClobs is 
    begin
        ind := vClobs.first;
        while ind is not null loop
            dbms_lob.freetemporary(vClobs(ind));
            ind := vClobs.next(ind);
        end loop;
    end;
    
begin
    -- обработаем переднный список генерируемых пакетов 
    for rec in (select * from 
        json_table(json_data, '$[*]' 
        columns packName    varchar2(2000)      path '$.package'        -- название пакета 
              , prefix      varchar2(2000)      path '$.prefix'         -- префикс для сообщений 
              , schem       varchar2(2000)      path '$.schema'         -- схема в которой надо создать пакет 
              , grants      clob format json    path '$.grants'         -- гранты на выполнение сего пакета 
              , syno        clob format json    path '$.synonyms'       -- синонимы в схемах на данный пакет 
              , servicePack varchar2(2000)      path '$.servicePackage' -- название сервисного пакета в который будет добавляться вызов функций пакета - если задан, то все генерируемые функции будут создаваться в сервисном слое 
              , tabs        clob format json    path '$.tables'         -- список таблиц по которым необходимо сформировать репозиторные функции 
        )) 
    loop
        vErrNum := 1;
        -- пакеты - создание пакета и его тела 
        addCode(cSpec,  'create or replace package %1.%2 is ',       tList(rec.schem, rec.packName), 0); -- спецификация пакета 
        addCode(cBody,  'create or replace package body %1.%2 is ',  tList(rec.schem, rec.packName), 0); -- тело пакета 
        -- константы что будут добавлены в спецификатцию пакета 
        addCode(cConst, 'cPrefix constant varchar2(200) := ''%1'';' || chr(10),     tList(rec.prefix, rec.packName)); -- спецификация пакета 
        
        -- TODO перенести в утиль пакет 
        vComment := '-- Поиск коммента таблицы ' || nl; 
        addCode(cProcSpec, vComment || '  function getTableCaption(pOwner varchar2, pTable varchar2) return varchar2;'); 
        addCode(cProcBody, vComment || 
                            '  function getTableCaption(pOwner varchar2, pTable varchar2) return varchar2 is '  || nl ||
                            '    vName varchar2(2000); '                                        || nl || 
                            '  begin '                                                          || nl || 
                            '    select comments into vName from all_tab_comments '             || nl ||
                            '    where table_name = upper(pTable) and owner = upper(pOwner);'   || nl ||
                            '    return vName;'                                                 || nl || 
                            '  exception '                                                      || nl || 
                            '    when no_data_found then  '                                     || nl || 
                            '      return pTable; '                                             || nl || 
                            '  end;'); 
        
        -- TODO перенести в утиль пакет 
        vComment := '-- Поиск коммента колонки ' || nl; 
        addCode(cProcSpec, vComment || '  function getFieldCaption(pOwner varchar2, pTable varchar2, pCol varchar2) return varchar2 ;'); 
        addCode(cProcBody, vComment || 
                            '  function getFieldCaption(pOwner varchar2, pTable varchar2, pCol varchar2) return varchar2  is '  || nl || 
                            '    vName varchar2(2000); '                                        || nl || 
                            '  begin '                                                          || nl || 
                            '    select comments into vName from all_col_comments '             || nl ||
                            '    where table_name = upper(pTable) and owner = upper(pOwner) '   || nl ||
                            '          and column_name = upper(pCol);'                          || nl ||
                            '    return vName;'                                                 || nl || 
                            '  exception '                                                      || nl || 
                            '    when no_data_found then  '                                     || nl || 
                            '      return pCol; '                                               || nl || 
                            '  end;'); 
        -- разберём массивы 
        fillList(vGrants, rec.grants);  -- гранты 
        -- попjлним скрипт грантами 
        if vGrants.count > 0 then 
            for i in vGrants.first..vGrants.last loop 
                addCode(cScript, 'grant execute on %1.%2 to %3;', tList(rec.schem, rec.packName, vGrants(i)), 0);
            end loop; 
        end if; 
        
        fillList(vSyno, rec.syno);    -- синонимы 
        -- попjлним скрипт синонимами 
        if vSyno.count > 0 then 
            for i in vSyno.first..vSyno.last loop 
                addCode(cScript, 'create or replace synonym %1.%2 for %3.%2;', tList(vSyno(i), rec.packName, rec.schem), 0);
            end loop; 
        end if;

        fillList(vTabs, rec.tabs, true);  -- таблицы 
        -- вот тут начинается жара - а потому наверное стоит попробовать вынести за пределы... а может и не надо выносить - добавим тут просто блок declare .. begin .. end;
        for i in vTabs.first..vTabs.last loop
            for tabrec in (select * from 
                json_table(vTabs(i) columns 
                    servicePackage  varchar2(2000)   path '$.servicePackage' -- название сервисного пакета в который попадают все функции и процедуры (если здесь это было указано 
                  , tName           varchar2(2000)   path '$.name'           -- название таблицы (схема.таблица)
                  , mapper          varchar2(2000)   path '$.mapper'         -- название маппера 
                  , shortName       varchar2(2000)   path '$.shortname'      -- макс. длина переменной - 30 символов... => делай выводы
                  , primaryKey      varchar2(2000)   path '$.primaykey'      -- ключевое поле 
                  , cSequence       varchar2(2000)   path '$.sequence'       -- сиквенс, который используется для ключевого поля 
                  , defFuncs        clob format json path '$.defaultfuncs'  -- список стнадартных функций 
                  , custFuncs       clob format json path '$.customfuncs'   -- список кастомных функций
            )) loop
                
                
                vOwner := lower(getLeks(tabrec.tname, 1));
                vTable := lower(getLeks(tabRec.tname, 2));
                vTableCaption := getTableCaption(vOwner, vTable);
                
                -- почистим старый массив и заполним всей доступной информацие по колонкам указанной таблицы 
                vTabCols.delete;
                ind := 0;
                for cols in (select * from all_tab_columns c where c.owner = upper(vOwner) and c.table_name = upper(vTable) order by column_id) loop
                    vTabCols(cols.column_name) := cols;
                    vTabColsNum(ind) := cols;
                    ind := ind + 1;
                end loop; 
                -- почистим старые комменты и заменим на комменты соответствующей таблицы 
                vTabComments.delete;
                for comms in (select column_name, comments from all_col_comments c where c.owner = upper(vOwner) and c.table_name = upper(vTable)) loop
                    vTabComments(comms.column_name) := comms.comments;
                end loop;
                
                -- Создание маппера - процедуры, котораая разрозненные данные превращает в понятную нам сущность с проверкаами 
                -- на типы данных, на размерность, на null, с возмоной подстановкой значения по умолчанию 
                -- В общем преобразуем входящий набор данных в конкретный табличный тип 
                vComment := '-- Маппер и Валидатор - для преобразования входных данных в заданную структуру с провеками этих данных' || nl;
                addCode2(cProcSpec, cProcBody, vComment || '  function %1(', tList(nvl(tabrec.mapper, nvl(tabrec.shortname, vTable) || '_mapper')), 1);
                
                vStrTemp := null; 
                f := false;
                for i in vTabColsNum.first..vTabColsNum.last loop
                    vStrTemp := case when f then ',' else ' ' end || 
                                'p' || lower(vTabColsNum(i).column_name) || ' in ' || vTabColsNum(i).data_type || 
                                case when vTabColsNum(i).nullable = 'Y' then ' := null' end;
                    addCode2(cProcSpec, cProcBody, lower(vStrTemp), null, 3);
                    f := true;
                end loop;
                
                addCode(cProcSpec,  ') return %1.%2%rowtype;' || chr(10), tList(vOwner, vTable));
                addCode(cProcBody,  ') return %1.%2%rowtype is '        || nl || 
                                    '    vRow %1.%2%rowtype;' || nl || 
                                    '  begin ',
                tList(vOwner, vTable));
                
                -- проставим валидаторы на типы данных и размерности полей 
                for i in vTabColsNum.first..vTabColsNum.last loop
                    case vTabColsNum(i).data_type 
                        when 'VARCHAR2' then 
                            addCode(cProcBody, 'vRow.%3 := assert.field_value_%4(''%1.%2.%3'', p%3, %5, pPrefix => cPrefix);', 
                                tList(vOwner, 
                                      vTable, 
                                      lower(vTabColsNum(i).column_name),
                                      lower(vTabColsNum(i).data_type),
                                      case vTabColsNum(i).nullable when 'N' then 'true' else 'false' end
                                ), pLevel => 2);
                        else -- для остальных полей стандартно 
                            -- присвоим значения по умолчанию если того потребуется 
                            if vTabColsNum(i).nullable = 'N' and vTabColsNum(i).data_default is not null then 
                                addCode(cProcBody, 
                                        'vRow.%1 := nvl(p%1, %2);', 
                                        tList(vTabColsNum(i).column_name, 
                                        vTabColsNum(i).data_default), 
                                        pLevel => 2);
                            else 
                                addCode(cProcBody, 'vRow.%1 := p%1;', tList(vTabColsNum(i).column_name), pLevel => 2);
                            end if; 
                            -- если не должно быть пустым то сделаем соответствующую проверку 
                            if vTabColsNum(i).nullable = 'N' then 
                                addCode(cProcBody,
                                        'assert.valid(p%3 is not null, tList(getFieldCaption(''%1'', ''%2'', ''%3''), cPrefix, errp.err_is_null));', 
                                        tList(vOwner, vTable, vTabColsNum(i).column_name), 
                                        pLevel => 2);
                            end if; 
                    end case;
                    addCode(cProcBody, '');
                end loop;
                
                addCode(cProcBody, 'return vRow;' || nl || '  end;' || nl, pLevel => 2);
                
                -- теперь пробежимся по дефолтным функциям 
                vPrimKeyName := nvl(tabrec.primarykey, 'Id');
                vPrimKeyType := case when not vTabCols.exists(upper(vPrimKeyName)) then 'number' else lower(vTabCols(upper(vPrimKeyName)).data_type) end;
                vSeqName     := nvl(tabrec.cSequence, nvl(tabrec.shortname, vTable) || '_seq');
                addSequence(vSeqName);
                
                -- можно просто сделать select into но мне не хочется - неявные укрсоры весьма удобная вещь
                for func in (select * from json_table(tabrec.DefFuncs, '$[*]' columns 
                    cType     varchar2(200) path '$.type',
                    cName     varchar2(200) path '$.name',
                    cPack     varchar2(200) path '$.servicePackage',
                    cOptions  varchar2(200) path '$.options'
                )) loop 
                    fillList(vOptions, func.cOptions); -- по каждой из функции получим свой набор опций 
                    
                    vFuncNames(func.cType) := nvl(func.cName, func.cType || '_' || nvl(tabrec.shortname, vTable)); 
                    case func.cType 
                        ------------------------------------------------------------------------------------------------------------------------
                        when cFunc_existsById then 
                            vComment := '-- Проверка на существование записи по первичному ключу ' || nl;
                            addCode(cProcSpec, vComment || '  function %1(p%4 %2.%3.%4%type, pRaise boolean := true) return boolean;' || nl, tList(vFuncNames(func.cType), vOwner, vTable, vPrimKeyName));
                            addCode(cProcBody, vComment || '  function %1(p%4 %2.%3.%4%type, pRaise boolean := true) return boolean is ' || nl|| 
                                          '      v%4     %2.%3.%4%type; '                                               || nl || 
                                          '  begin '                                                                    || nl || 
                                          '      select %4 into v%4 from %2.%3 where %4 = p%4; '                        || nl || 
                                          '      return true; '                                                         || nl || 
                                          '  exception '                                                                || nl || 
                                          '    when no_data_found then '                                                || nl || 
                                          '      if pRaise then '                                                       || nl || 
                                          '        errp.do(cPrefix, err_%5_not_exists_by_%4, tList(p%4)); '             || nl || 
                                          '      else '                                                                 || nl || 
                                          '        return false; '                                                      || nl || 
                                          '      end if; '                                                              || nl || 
                                          '  end; '                                                                     || nl,
                                          tList(vFuncNames(func.cType), 
                                                vOwner, 
                                                vTable, 
                                                vPrimKeyName, 
                                                nvl(tabrec.shortname, vTable)));
                            addCode(cConst, 
                                    'err_%1_not_exists_by_%2 constant number := %3; -- Записи "%4" с идентификатором "$\1" не существует', 
                                    tList(  nvl(tabrec.shortname, vTable),
                                            vPrimKeyName,
                                            vErrNum, 
                                            vTableCaption));
                            vErrNum := vErrNum + 1;
                        ------------------------------------------------------------------------------------------------------------------------
                        when cFunc_findById then 
                            vComment := '-- Поиск записи по первичному ключу ' || nl;
                            addCode(cProcSpec, vComment || '  function %1(p%4 %2.%3.%4%type, pRaise boolean := true) return %2.%3%rowtype;' || nl, tList(vFuncNames(func.cType), vOwner, vTable, vPrimKeyName));
                            addCode(cProcBody, vComment || '  function %1(p%4 %2.%3.%4%type, pRaise boolean := true) return %2.%3%rowtype is ' || nl|| 
                                          '      vRow %2.%3%rowtype;'                                               || nl || 
                                          '  begin '                                                                || nl || 
                                          '      select * into vRow from %2.%3 where %4 = p%4; '                    || nl || 
                                          '      return vRow; '                                                     || nl || 
                                          '  exception '                                                            || nl || 
                                          '      when no_data_found then  '                                         || nl || 
                                          '          if pRaise then '                                               || nl || 
                                          '              errp.do(cPrefix, err_%5_not_found_by_id, tList(p%4)); '    || nl || 
                                          '          else '                                                         || nl || 
                                          '              return null; '                                             || nl || 
                                          '          end if; '                                                      || nl || 
                                          '  end;'                                                                  || nl, 
                                          tList(vFuncNames(func.cType), 
                                                vOwner, 
                                                vTable, 
                                                vPrimKeyName, 
                                                nvl(tabrec.shortname, vTable)));
                            addCode(cConst, 
                                    'err_%1_not_found_by_id constant number := %2; -- Не найдена запись в "%3" с идентификатором "$\1"', 
                                    tList(  nvl(tabrec.shortname, vTable),
                                            vErrNum, 
                                            vTableCaption));
                            vErrNum := vErrNum + 1;
                        ------------------------------------------------------------------------------------------------------------------------
                        when cFunc_add then 
                            vComment := '-- Добавление новой записи ' || nl;
                            addCode(cProcSpec, vComment || '  function %1(pRow %3.%4%rowtype, pRaise boolean := true) return %3.%4%rowtype;' || nl, tList(vFuncNames(func.cType), ' ', vOwner, vTable));
                            addCode(cProcBody, vComment || '  function %1(pRow %3.%4%rowtype, pRaise boolean := true) return %3.%4%rowtype is '|| nl|| 
                                          '    vRow %3.%4%rowtype := pRow; '                                                    || nl || 
                                          '  begin '                                                                            || nl || 
                                          '    if vRow.%5 is null then  '                                                       || nl || 
                                          '        vRow.%5 := %6.nextval; '                                                     || nl || 
                                          '    end if; '                                                                        || nl || 
                                          '    insert into %3.%4 values vRow; '                                                 || nl || 
                                          '    return %2(vRow.%5); '                                                            || nl || 
                                          '  exception '                                                                        || nl || 
                                          '    when errp.appException then  '                                                   || nl || 
                                          '        if pRaise then raise; else return null; end if;  '                           || nl || 
                                          '    when others then  '                                                              || nl || 
                                          '        if pRaise then errp.unhandled(tList()); else return null; end if; '          || nl || 
                                          '  end;  '                                                                            || nl,
                                    tList(vFuncNames(func.cType), 
                                          vFuncNames(cFunc_findById), 
                                          vOwner, 
                                          vTable, 
                                          vPrimKeyName, 
                                          vSeqName));
                        ------------------------------------------------------------------------------------------------------------------------
                        when cFunc_update then 
                            vComment := '-- Обновление записи' || nl;
                            addCode(cProcSpec, vComment || '  function %1(pRow %2.%3%rowtype, pRaise boolean := true, pUpsert boolean := false) return %2.%3%rowtype;' || nl, tList(vFuncNames(func.cType), vOwner, vTable, vPrimKeyName, vFuncNames(cFunc_findById)));
                            addCode(cProcBody, vComment || '  function %1(pRow %2.%3%rowtype, pRaise boolean := true, pUpsert boolean := false) return %2.%3%rowtype is '|| nl|| 
                                          '  begin '                                                    || nl|| 
                                          '    update %2.%3 set  ', 
                                          tList(vFuncNames(func.cType), vOwner, vTable, vPrimKeyName, vFuncNames(cFunc_findById)));
                            for i in vTabColsNum.first..vTabColsNum.last loop
                                if vTabColsNum(i).column_name != upper(vPrimKeyName) then 
                                    addCode(cProcBody, ' %1 = pRow.%1' || case when i != vTabColsNum.last then ',' end, 
                                            tList(lower(vTabColsNum(i).column_name)), 3); 
                                end if; 
                            end loop; 
                            addCode(cProcBody,
                                          '    where %4 = pRow.%4; '         || nl|| 
                                          '      if sql%notfound and pUpsert then ' || nl|| 
                                          '         return %6(pRow, pRaise);' || nl|| 
                                          '      end if; ' || nl|| 
                                          '      return %5(pRow.%4, pRaise); ' || nl|| 
                                          '  end;'                           || chr(10),
                                          tList(vFuncNames(func.cType), 
                                                vOwner, 
                                                vTable, 
                                                vPrimKeyName, 
                                                vFuncNames(cFunc_findById), 
                                                vFuncNames(cFunc_add)));
                        ------------------------------------------------------------------------------------------------------------------------
                        when cFunc_delete then 
                            vComment := '-- Удаление записи' || nl;
                            addCode(cProcSpec, vComment || '  procedure %1(p%4 %2.%3.%4%type, pRaise boolean := true);' || nl, tList(vFuncNames(func.cType), vOwner, vTable, vPrimKeyName));
                            addCode(cProcBody, vComment || '  procedure %1(p%4 %2.%3.%4%type, pRaise boolean := true) is '|| nl|| 
                                          '  begin '                                                        || nl || 
                                          '      if %5(p%4, pRaise) then '                                  || nl || 
                                          '        delete from %2.%3 where %4 = p%4; '                      || nl || 
                                          '      end if; '                                                  || nl || 
                                          '  end; '                                                         || nl,
                                          tList(vFuncNames(func.cType), 
                                                vOwner, 
                                                vTable, 
                                                vPrimKeyName, 
                                                vFuncNames(cFunc_existsById)));
                        ------------------------------------------------------------------------------------------------------------------------
                        when cFunc_findByUnique then 
                            declare 
                                vFuncNameTemp varchar2(2000);
                                vStrFields    varchar2(2000);
                                vStrEquals    varchar2(2000);
                                vFields       varchar2(2000);
                                vCount        number := 0;
                            begin
                                -- пробежимся по уникальным индексам 
                                for uniq in (   select i.index_name
                                                from all_indexes i  
                                                where   i.table_name  = upper(vTable) 
                                                    and i.table_owner = upper(vOwner) 
                                                    and i.uniqueness  = 'UNIQUE')
                                loop
                                    vFuncNameTemp := nvl(func.cName, 'find' || '_' || nvl(tabrec.shortname, vTable)) || '_by';  
                                    vStrFields := null;
                                    vStrEquals := null;
                                    vFields    := null;
                                    
                                    vTempTabCols := tList();
                                    -- формируем список колонок индекса 
                                    select column_name bulk collect into vTempTabCols
                                    from all_ind_columns c 
                                    where c.table_name  = upper(vTable) and 
                                          c.table_owner = upper(vOwner) and 
                                          c.index_name  = uniq.index_name
                                    order by column_position; 
                                    
                                    --  если у нас нет составного ключевого поля и задан findById и ткущий набор полей являетяс индексом по ключевому полю - то его проппускаем 
                                    if  vFuncNames.exists(cFunc_findById) and vTempTabCols.count = 1 
                                        and vTempTabCols(vTempTabCols.first) = upper(vPrimKeyName) 
                                    then 
                                        continue;
                                    end if; 
                                    
                                    -- пробежимся по всем полученным полям 
                                    for i in vTempTabCols.first..vTempTabCols.last loop
                                        -- список полей 
                                        vStrFields := vStrFields || case when vStrFields is not null then ', ' end || 
                                                    'p'|| vTempTabCols(i) || ' '  ||  vTabCols(vTempTabCols(i)).data_type;
                                        -- условия в разделе where 
                                        vStrEquals := vStrEquals || case when vStrEquals is not null then ' and ' end || 'vRow.' || vTempTabCols(i) || ' = ' || 'p' || vTempTabCols(i);
                                        -- перечень входных параметров
                                        vFields := vFields || case when vFields is not null then ', ' end || 'p' || vTempTabCols(i);
                                        -- название процедуры - будет немного стрёмное - но его всегда можно будет заменить в генерируемом коде 
                                        vFuncNameTemp := vFuncNameTemp || '_' || 
                                                         case when existsList(vOptions, 'funcShortFields') then  substr(vTempTabCols(i), 1, 5) -- ограничим пока 5-ю первыми символами с каждого поля
                                                              else vTempTabCols(i) -- или же полностью поля использовать в названии функции без обрезки 
                                                        end; 
                                    end loop; 
                                    vFuncNameTemp := substr(vFuncNameTemp, 1, 30); -- ограничение на 30 символов у оракла 
                                    
                                    vComment := '-- Поиск значения по уникальному индексу ' || nl;
                                    addCode(cProcSpec, vComment || '  function %1(%4, pRaise boolean := true) return %2.%3%rowtype;' || nl, tList(lower(vFuncNameTemp), vOwner, vTable, lower(vStrFields)));
                                    addCode(cProcBody, vComment || '  function %1(%4, pRaise boolean := true) return %2.%3%rowtype is ' || nl || 
                                                  '    vRow %2.%3%rowtype;'                                     || nl || 
                                                  '  begin '                                                    || nl || 
                                                  '      select * into vRow from %2.%3 '                        || nl || 
                                                  '      where %5;'                                             || nl || 
                                                  '      return vRow; '                                         || nl || 
                                                  '  exception '                                                || nl || 
                                                  '      when no_data_found then  '                             || nl || 
                                                  '          if pRaise then '                                   || nl || 
                                                  '              errp.do(cPrefix, err_%6_not_found_by_fields, tList(%7)); ' || nl || 
                                                  '          else '                                                         || nl || 
                                                  '              return null; '                                             || nl || 
                                                  '          end if; '                                                      || nl || 
                                                  '  end;'                                                                  || nl, 
                                                  tList(lower(vFuncNameTemp), 
                                                        vOwner, 
                                                        vTable, 
                                                        lower(vStrFields), 
                                                        lower(vStrEquals), 
                                                        lower(nvl(tabrec.shortname, vTable)), 
                                                        lower(vFields)));
                                    vCount := 1;
                                end loop;
                                addCode(cConst, 
                                        'err_%1_not_found_by_fields constant number := %2; -- Не найдена запись в "%3" по ункальному индексу ', 
                                        tList(  nvl(tabrec.shortname, vTable),
                                                vErrNum, 
                                                vTableCaption));
                                vErrNum := vErrNum + 1;
                            end;
                        ------------------------------------------------------------------------------------------------------------------------
                        -- when 'findAllByFk'      then null; -- pipelined функция возвращающая все значения по заданному значению внешнего ключа 
                        ------------------------------------------------------------------------------------------------------------------------
                        -- when 'findFirstByFK'    then null; -- поиск первой записи по значению внешнего ключа отсортированного по первичному ключу 
                        ------------------------------------------------------------------------------------------------------------------------
                        -- when 'existsByUnique'   then null; -- функции проверки существования значения по уникальном индексам 
                        ------------------------------------------------------------------------------------------------------------------------
                        -- when 'existsByFK'       then null; -- функции проверки существования записей связанных с внешними ключами 
                        ------------------------------------------------------------------------------------------------------------------------
                        else null;
                    end case;
                    
                end loop; 
            end loop; 
        end loop; 
        -- теперь когда у нас есть списки всего необходимого можно присутпить к разбору дерева и генерации соответствующего кода пакетов 
        
        -- сформируем итоговые CLOB-ы
        dbms_lob.append(vClobs(cSpec), vClobs(cConst));
        dbms_lob.append(vClobs(cSpec), nl);
        dbms_lob.append(vClobs(cSpec), vClobs(cProcSpec));
        dbms_lob.append(vClobs(cBody), vClobs(cProcBody));
        
        addCode2(cSpec, cBody, 'end;', pLevel => 0);

        dbms_output.put_line(vClobs(cSpec));
        dbms_output.put_line(vClobs(cBody));
        dbms_output.put_line(vClobs(cScript));

        -- почистим получившиеся скрипты 
        clearClobs;
    end loop; 
end; 
