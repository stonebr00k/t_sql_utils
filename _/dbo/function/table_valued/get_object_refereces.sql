/*§ Description
    Returns all references to or from the supplied object_id.
    Uses system view `sys.sql_expression_dependencies`.

    If @type = 'from', it will return a list of objects that the supplied object directly references
    If @type = 'to', it will return a list of object that directly recerences to the supplied object 
*/
create or alter function dbo.get_object_refereces (
    @object_id int,             --§ Any object_id
    @type varchar(10) = 'from'  --§ Reference type, valid options are 'from' and 'to'
)
returns table
as return (
    select distinct [object_id]
        ,[schema_name]
        ,[object_name]
        ,[is_schema_bound_reference]
    from (
        select [object_id] = referenced_id
            ,[schema_name] = object_schema_name(referenced_id)
            ,[object_name] = object_name(referenced_id)
            ,is_schema_bound_reference = is_schema_bound_reference
        from sys.sql_expression_dependencies
        where @type = 'from'
            and referencing_id = @object_id
            and referenced_id is not null
        union all
        select [object_id] = referencing_id
            ,[schema_name] = object_schema_name(referencing_id)
            ,[object_name] = object_name(referencing_id)
            ,is_schema_bound_reference = is_schema_bound_reference
        from sys.sql_expression_dependencies
        where @type = 'to'
            and referenced_id = @object_id
            and referencing_id is not null
    ) x
);
go
