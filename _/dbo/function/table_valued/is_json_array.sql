/*§ Description
    Returns true if supplied @json parameter is a JSON array, else returns false.
*/
create or alter function dbo.is_json_array (
    @json nvarchar(max)
)
returns table
with schemabinding
as return (
    select [value] = cast(iif([type] = 4, 1, 0) as bit)
    from openjson(json_modify(N'[]', N'append $', json_query(iif(isjson(@json) = 1, @json, null))))
);
go
