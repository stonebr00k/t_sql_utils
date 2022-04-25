/*§ Description
    Eliminates repeated occurances of the given character in the given string.
*/
/*§ Usage
    This query:
    ```sql
    select [value] from dbo.prune_repeated_chars(N'foo      bar', N' ');
    ```
    will return:
    ```
    foo bar
    ```
*/
/*§ Explanation of logic
    Let's say that we want to transform the string `A___B` (3 underscores) into `A_B` (1 underscore).
    To illustrate, we will use the character `<` instead of nchar(17) and `>` instead of nchar(18):

    1. First, we replace all `_` with `<>` => `A<><><>B`
    2. Then we remove all instances of the reverse `><` => `A<>B`
    3. And lastly we replace all instances of `<>` with the original `_` => `A_B`

    But since the characters nchar(17) and nchar(18) are far less common in strings than `<` and `>` are, we use those instead.
*/
create or alter function dbo.prune_repeated_chars (
    @string nvarchar(max),  --§ String to be pruned
    @char nchar(1)          --§ Character to eliminate repetitions of
)
returns table
with schemabinding
as return (
    select [value] = replace(replace(replace(@string,
        --§ Replace all instances of @char in @string with the combination nchar(17) + nchar(18)
        @char, nchar(17) + nchar(18)),
        --§ Then, remove all instances of the reverse combination nchar(18) + nchar(17)
        nchar(18) + nchar(17), N''),
        --§ Lastly, replace all instances of the combination nchar(17) + nchar(18) with the original @char
        nchar(17) + nchar(18), @char)
);
go
