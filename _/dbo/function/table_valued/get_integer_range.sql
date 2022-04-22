/*§ Description
    Returns a table containing a column with all integers between start and end input.
*/
create or alter function dbo.get_integer_range (
    @start bigint,  --§ First integer in range
    @end bigint     --§ Last integer in range
)
returns table
as return (
    with 
        e1(n) as (select 1 union all select 1),      --2
        e2(n) as (select 1 from e1 cross join e1 x), --4
        e3(n) as (select 1 from e2 cross join e2 x), --16
        e4(n) as (select 1 from e3 cross join e3 x), --256
        e5(n) as (select 1 from e4 cross join e4 x), --65 536
        e6(n) as (select 1 from e5 cross join e5 x), --4 294 967 296
        e(n) as (select top (abs(@end - (@start - 1))) cast(row_number() over (order by (select null)) as bigint) from e6)

    select [value] = n + (@start - 1)
    from e
);
go
