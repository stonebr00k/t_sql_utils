/*§ Description
    Replaces all line endings in the supplied string with the desired character(s).
    Replaces Windows (crlf), Unix (lf) and Mac (cr) line endings
*/
create or alter function dbo.normalize_line_endings (
    @string nvarchar(max),      --§ Any string
    @char nvarchar(10) = null   --§ Character(s) to replace line endings with
)
returns table
as return (
    with le as (
        select cr = nchar(13)
            ,lf = nchar(10)
            ,crlf = nchar(13) + nchar(10)
            ,tchar = isnull(@char, nchar(10))
    )

    select [value] = replace(replace(replace(@string,
        crlf, tchar),
        cr, tchar),
        lf, tchar)
    from le
);
go
