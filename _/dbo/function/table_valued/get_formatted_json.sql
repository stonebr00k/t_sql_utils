/*§ Description
    Returns a formatted JSON string from JSON input.

    NOTE: If you're on SQL Server version 2017 or later, replace the `stuff()` function call with `string_agg()`.
*/
/*§ Options
    ```json
    {
        "minify": "(bool) If true will return minified JSON, if false will return beautified JSON. Defaults to false",
        "indentation_size": "(int) The indentation size to use. Has no effect if "minify" is true. Defaults to 4",
        "return_as_string": If true will return a single row containing the full JSON, else returns a table. Defaults to false."
    }
    ```
*/
create or alter function dbo.get_formatted_json (
    @json_string nvarchar(max), --§ Any JSON string
    @options nvarchar(max)      --§ JSON string containing options
)
returns table
as return (
    with options as (
        select minify = cast(isnull(json_value(@options, N'$.minify'), 0) as bit)
            ,indentation_size = cast(isnull(json_value(@options, N'$.indentation_size'), 4) as tinyint)
            ,return_as_string = cast(isnull(json_value(@options, N'$.return_as_string'), 0) as bit)
    )
    ,formatter as (
        select idx = row_number() over(order by y.hid)
            ,[value] = iif(o.minify = 0,replicate(N' ',o.indentation_size * p.[level]),N'')
                + iif(is_array_item = 0 and isnull(x.i, 0) = 0, isnull(N'"' + string_escape([key], 'json') + N'":' + iif(o.minify = 0, N' ', N''), N''), N'')
                + case [type]
                    when 5 then iif(isnull(x.i, 0) = 0, N'{',N'}') + iif(has_children = 0, N'}', N'')
                    when 4 then iif(isnull(x.i, 0) = 0, N'[',N']') + iif(has_children = 0, N']', N'')
                    when 1 then N'"' + string_escape([value], 'json') + N'"'
                    when 0 then N'null'
                    else [value]
                    end 
                + iif(hierarchy_id = max(hierarchy_id) over(partition by hierarchy_id.GetAncestor(1)) or x.i = 0, N'', N',')
        from dbo.open_json_full(@json_string, N'{"include_root":true}') p
        left join (values(0), (1)) x(i)
            on p.has_children = 1
        cross apply (
            select hid = iif(isnull(x.i, 0) = 0,
                p.hierarchy_id,
                hierarchyid::Parse(p.hierarchy_id.GetAncestor(1).ToString() + cast(p.item_no + 0.5 as nvarchar(16)) + N'/')
            )
        ) y
        cross join options o
        where o.minify = 0 or p.[type] != 0
    )

    select idx = f.idx
        ,[value] = f.[value]
    from options o
    cross join formatter f
    where o.return_as_string = 0
    union all
    select idx = 1
        ,[value] = stuff((
            select iif(o.minify = 0 or f.idx = 1, nchar(13) + nchar(10), N'') + [value]
            from formatter f
            order by f.idx
            for xml path(''), type
        ).value('.', 'nvarchar(max)'), 1, 2, '')
    from options o
    where o.return_as_string = 1
);
go
