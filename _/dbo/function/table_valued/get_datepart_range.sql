/*§ Description
    Returns a table of date ranges.
*/
create or alter function dbo.get_datepart_range (
    @datepart varchar(20),  --§ Any of: 'date', 'day', 'week', 'iso_week', 'month', 'quarter', 'year'
    @start_date date,       --§ First day in range
    @end_date date          --§ Last day in range
)
returns table
as return (
    with date_diff as (
        select [value] = case 
                when @datepart in ('date', 'day') then datediff(day, @start_date, @end_date)
                when @datepart in ('week', 'iso_week') then datediff(day, @start_date, @end_date) / 7
                when @datepart = 'month' then datediff(month, @start_date, @end_date)
                when @datepart = 'quarter' then datediff(quarter, @start_date, @end_date)
                when @datepart = 'year' then datediff(year, @start_date, @end_date)
                end
    )

    select id = cast(id as int)
        ,[start_date] = cast([start_date] as date)
        ,[end_date] = cast([end_date] as date)
        ,days_in_period = datediff(day,[start_date],[end_date]) + 1
    from (
        -- @datepart = date/day
        select id = year(d.dt) * 10000 + month(d.dt) * 100 + day(d.dt)
            ,[start_date] = d.dt
            ,[end_date] = d.dt
        from date_diff dd
        cross apply dbo.get_integer_range(0, dd.[value]) i
        cross apply (select dt = dateadd(day, i.[value], @start_date)) d
        where @datepart in ('date', 'day')
        union all
        -- @datepart = week or iso_week
        select id = year(dateadd(day, 26 - datepart(iso_week, bd.[start_date]), bd.[start_date])) * 100 + datepart(iso_week, d.dt)
            ,[start_date] = bd.[start_date]
            ,[end_date] = bd.[end_date]
        from date_diff dd
        cross apply dbo.get_integer_range(0, dd.[value]) i
        cross apply (select dt = dateadd(week, i.[value], @start_date)) d
        cross apply (
            select [start_date] = iif(i.[value] = 0, @start_date, dateadd(day, - (datepart(weekday, d.dt) + @@datefirst + 5) % 7, d.dt))
                ,[end_date] = iif(i.[value] = dd.[value], @end_date, dateadd(day, 6 - (datepart(weekday, d.dt) + @@datefirst + 5) % 7, d.dt))
        ) bd
        where @datepart in ('week', 'iso_week')
        union all
        -- @datepart = month
        select id = year(d.dt) * 100 + month(d.dt)
            ,[start_date] = iif(i.[value] = 0, @start_date, datefromparts(year(d.dt), month(d.dt), 1))
            ,end_date = iif(i.[value] = dd.[value], @end_date, eomonth(d.dt))
        from date_diff dd
        cross apply dbo.get_integer_range(0, dd.[value]) i
        cross apply (select dt = dateadd(month, i.[value], @start_date)) d
        where @datepart = 'month'
        union all
        -- @datepart = quarter
        select id = year(d.dt) * 10 + datepart(quarter, d.dt)
            ,[start_date] = iif(i.[value] = 0, @start_date, datefromparts(year(d.dt), 3 * datepart(quarter, d.dt) - 2, 1))
            ,end_date = iif(i.[value] = dd.[value], @end_date, eomonth(datefromparts(year(d.dt), 3 * datepart(quarter,d.dt), 1)))
        from date_diff dd
        cross apply dbo.get_integer_range(0, dd.[value]) i
        cross apply (select dt = dateadd(quarter, i.[value], @start_date)) d
        where @datepart = 'quarter'
        union all
        -- @datepart = year
        select id = year(d.dt)
            ,[start_date] = iif(i.[value] = 0, @start_date, datefromparts(year(d.dt), 1, 1))
            ,end_date = iif(i.[value] = dd.[value], @end_date, datefromparts(year(d.dt), 12, 31))
        from date_diff dd
        cross apply dbo.get_integer_range(0, dd.[value]) i
        cross apply (select dt = dateadd(year, i.[value], @start_date)) d
        where @datepart = 'year'
    ) x
);
go
