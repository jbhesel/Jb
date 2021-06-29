# Jb

# Bookmarks for edited files

vim.log gets a line for every writing of a file

JbEdit uses the vim.log to find matching files and fzf to find text inside those
files. You type ":Je init.vim#fzf" and you will be shown your vimrc and the
positions of the string fzf. 

You could also write a bookmark in an arbitrary file and link to "init.vim#fzf" 
by putting your cursor on that text and start the function with ":Je ." or
<leader>je.

The bookmark has two parts. The first part is a search expression for the file
The second part is the text, that is search in these files. If you use a dot for
one part, it is a wild card for all. ".#matrix" searches for matrix in all the 
files. "matrix#." lists the first line of all files. You can omit the following
"#.". "matrix" shows all files containing matrix in filename or path.

The workflow is similar to google the web, exept the database are all your edited
files.

I don't use the shada file of vim with the history of all visited files,
because this also has all files I only have read.
Maybe this could be an extra function. I would increase the amount of remembered
files with "set viminfo='100,<50,s10,h" to get a list of theses files in 
vimscript you can use v:oldfiles.

# Bookmarks for WWW in markdown.

The plugin assumes, you put all interesting Internetsites in a Markdownfile
You type ":Jl junegunn" and will see all your bookmarks, that contain junegunn
in the url or the text to this url on the same line. With <cr> you start
browsing this website.

# Dependencies

vim plugin .#junegunn/fzf
shell programm .#ripgrep
