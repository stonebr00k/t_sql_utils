/*§ Description
    A table-valued function that splits a string into rows of substrings, based on a specified separator character.

    Unlike the built-in string_split-function, this function supports multiple characters as separator.
    You can also escape occurances of @separator in the @string by adding a backslash (\) in front of the character(s)
    where there would be a split if you don't escape it. It also returns an index-colum with guaranteed correct order 
    of the elements.
    
    NOTE! If the separator length is exactly one character and you don't need escaping or the idx-column, use built-in 
    function `string_split()` instead.
    
    NOTE 2! In the unlikely event your @string contains the unicode character u0011 (nchar(17), "device control one"), 
    this function will return your @separator instead in those places.
*/
/*§ Usage
    ```sql
    declare @string nvarchar(max) = N'this, is, a, list, of, words, this comma:\, will not cause a split';
    declare @separator nvarchar(128) = N',';

    select idx, [value] from dbo.split_string(@string, @separator);
    ```
*/
create or alter function dbo.split_string (
    @string nvarchar(max),      --§ Any string
    @separator nvarchar(128)    --§ Any string, max 128 characters
)
returns table
with schemabinding
as return (
    select idx = cast([key] as bigint) + 1
        ,[value] = replace([value], nchar(17), @separator)
    from openjson(N'["' + replace(replace(string_escape(@string, 'json'),
        --§ Replace all instances of '\' + @separator with character nchar(17)
        string_escape(N'\' + @separator, 'json'), N'\u0011'),
        --§ Replace all instances of @separator with N'","'
        string_escape(@separator, 'json'), N'","') +
    N'"]')
);
go
