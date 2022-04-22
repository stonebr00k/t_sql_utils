/*§ Description
    Returns a hierarchy of object references to or from the given object.go

    If @type = 'from', it will return a hierarchy of objects that the supplied object directly references
    If @type = 'to', it will return a hierarchy of object that directly recerences to the supplied object
*/
/*§ Options
    ```json
    {
        "schema_bound_only": "bool, if true will return only schema bound references",
        "max_levels": "int, will only go this many levels deep, 0 means unlimited.",
        "include_root": "bool, if true will include the given root-object in the hierarchy"
    }
    ```
*/
create or alter function dbo.get_object_referece_hierarchy (
    @object_id int,             --§ Any object_id
    @type varchar(10) = 'from', --§ Reference type, valid options are 'from' and 'to'
    @options nvarchar(max)      --§ JSON options, see "Options" section
)
returns table
as return (
    with [references] as (
        select hierarchy_id = cast(N'/' as nvarchar(max))
            ,[object_id] = @object_id
            ,[schema_name] = object_schema_name(@object_id)
            ,[object_name] = object_name(@object_id)
            ,is_schema_bound_reference = isnull(cast(json_value(@options, N'$.schema_bound_only') as bit), 0)
            ,lvl = 0
            ,max_levels = isnull(cast(json_value(@options, N'$.max_levels') as int), 0)
            ,include_root = isnull(cast(json_value(@options, N'$.include_root') as bit), 0)
        union all
        select hierarchy_id = d.hierarchy_id + cast(row_number() over(order by r.[schema_name], r.[object_name]) as nvarchar(13)) + N'/'
            ,[object_id] = r.[object_id]
            ,[schema_name] = r.[schema_name]
            ,[object_name] = r.[object_name]
            ,is_schema_bound_reference = r.is_schema_bound_reference
            ,lvl = d.lvl + 1
            ,max_levels
            ,include_root
        from [references] d 
        cross apply dbo.get_object_refereces(d.[object_id], @type) r
        where iif(d.[object_id] = r.[object_id], 0, 1) = 1
            and (d.is_schema_bound_reference = 0 or r.is_schema_bound_reference = 1)
            and (d.max_levels = 0 or d.lvl < d.max_levels)
    )

    select hierarchy_id = cast(hierarchy_id as hierarchyid)
        ,[object_id]
        ,[schema_name]
        ,[object_name]
        ,is_schema_bound_reference
        ,lvl
    from [references]
    where isnull(include_root, 0) = 1
        or cast(iif([object_id] = @object_id, 0, 1) as bit) = 1
);
go
