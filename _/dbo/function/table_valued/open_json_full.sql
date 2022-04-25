/*§ Description
    Uses built in function `openjson()` to parse a JSON string. 
    Unlike the built in function, this function parses the entire JSON tree instead of just the first level.
    It also provides more information about each node of the tree.
    It contains a recursive CTE, so if your structure is more than 100 levels deep, you'll need to add `option (maxrecursion 0)` to your query.
*/
/*$ Columns
    |Column         |Datatype       |Description                                                        |
    |:--------------|:--------------|:------------------------------------------------------------------|
    |hiearchy_id    |hierarchyid    |A hierarchical id of the node in the tree. Root is /1/.            |
    |parent_path    |nvarchar(max)  |Path to the node parent.                                           |
    |key            |nvarchar(4000) |Key name. If parent is array the index of the item is returned.    |
    |value          |nvarchar(max)  |Value from built in function `openjson`.                           |
    |type           |tinyint        |Type from built in function `openjson`.                            |
    |level          |int            |Tree level. Root is 0.                                             |
    |item_no        |bigint         |The order number of the item in its parent object/array.           |
    |is_array_item  |bit            |True if the parent collection is an array.                         |
    |has_children   |bit            |True if the the node is an object or array and it has child nodes. |
    |is_object      |bit            |True if the the node is an object.                                 |
    |is_array       |bit            |True if the the node is an array.                                  |
*/
/*$ Options
    ```json
    {
        "max_level": "(int) Maximum levels to parse. 0 means no limit. Defaults to 0.",
        "include_root": "(bool) If true will include root in the results. Defaults to false.",
        "include_leaves_only": "(bool) If true will only return leaf nodes. Defaults to false",
        "include_null_values": "(bool) If true, null values will be included. Defaults to false.",
        "hide_json_values": "(bool) If true, the value column of object and array nodes will be null."
    }
    ```
*/
create or alter function dbo.open_json_full (
    @json_string nvarchar(max),     --§ Any JSON string
    @options nvarchar(4000) = null  --§ JSON string containing options
)
returns table
as return (
    --§ Get options from JSON input
    with options as (
        select max_level = cast(isnull(json_value(@options,N'$.max_level'), 0) as int)
            ,include_root = cast(isnull(json_value(@options,N'$.include_root'), 0) as bit)
            ,include_leaves_only = cast(isnull(json_value(@options,N'$.include_leaves_only'), 0) as bit)
            ,[include_null_values] = cast(isnull(json_value(@options,N'$.include_null_values'), 1) as bit)
            ,hide_json_values = cast(isnull(json_value(@options,N'$.hide_json_values'), 0) as bit)
    ),
    --§ Recursively traverse the JSON tree, one level at a time.
    parser as (
        select hid_str = cast(N'/1/' as nvarchar(4000))
            ,parent_path = cast(N'$' as nvarchar(max)) collate database_default
            ,[key] = cast(null as nvarchar(4000))
            ,[value] = cast(@json_string as nvarchar(max))
            ,[type] = cast(iif(i.[value] = 1, 5, 4) as tinyint)
            ,[level] = 0
            ,item_no = cast(1 as bigint)
            ,is_array_item = cast(0 as bit)
            ,has_children = cast(iif(exists (select 1 from openjson(@json_string)), 1, 0) as bit)
        from dbo.is_json_object(@json_string) i
        cross join options o
        where isjson(@json_string) = 1
        union all
        select hid_str = cast(p.hid_str + cast(iif(p.[type] = 4,
                try_cast(j.[key] as bigint) + 1,
                row_number() over(partition by p.hid_str order by (select null))
            ) as varchar(13)) + N'/' as nvarchar(4000))
            ,parent_path = p.parent_path + isnull(N'.' + p.[key], N'')
            ,[key] = j.[key] collate database_default
            ,[value] = j.[value]
            ,[type] = cast(j.[type] as tinyint)
            ,[level] = p.[level] + 1
            ,item_no = cast(iif(p.[type] = 4,
                try_cast(j.[key] as bigint) + 1,
                row_number() over(partition by p.hid_str order by (select null))
            ) as bigint)
            ,is_array_item = cast(iif(p.[type] = 4, 1, 0) as bit)
            ,has_children = cast(iif(j.[type] in (4, 5) and exists (select 1 from openjson(j.[value])), 1, 0) as bit)
        from parser p
        cross apply openjson(p.[value]) j
        cross join options o
        where p.[type] in (4, 5)
            and (o.max_level = 0 or p.[level] < o.max_level)
    )

    select hierarchy_id = hierarchyid::Parse(p.hid_str)
        ,parent_path = iif(p.[level] = 0, null, p.parent_path)
        ,[key] = iif(p.is_array_item = 1, quotename(p.[key]), p.[key])
        ,[value] = iif([type] in (4, 5) and o.hide_json_values = 1, null, [value])
        ,[type] = p.[type]
        ,[level] = p.[level]
        ,item_no = item_no
        ,is_array_item = is_array_item
        ,has_children = has_children
        ,is_object = cast(iif([type] = 5, 1, 0) as bit)
        ,is_array = cast(iif([type] = 4, 1, 0) as bit)
    from parser p
    cross join options o
    where (o.include_root | cast(p.[level] as bit) = 1)
        and (o.[include_null_values] | cast(p.[type] as bit) = 1)
        and (o.include_leaves_only & p.has_children = 0)
);
go
