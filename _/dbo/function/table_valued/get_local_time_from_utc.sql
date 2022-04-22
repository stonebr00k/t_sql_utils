/*§ Description
    Returns the local datetime of the db server from a supplied UTC datetime.
*/
create or alter function _.get_local_time_from_utc (
    @utc_datetime datetime2(7)
)
returns table
as return (
    select [value] = cast(switchoffset(cast(@utc_datetime as datetimeoffset), datename(tzoffset, sysdatetimeoffset())) as datetime2(7))
);
go
