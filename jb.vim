" Jb start vimlog ----------------------------------------------------------------------
" global Variables
if !exists("g:Jb_Linkfname")
    let g:Jb_Linkfname = '/qsx/intra/2020/vimwiki/jbarbeit.md'
endif
if !exists("g:Jb_logfname")
    let g:Jb_logfname = '/home/'.$USER.'/vim.log' " eg /home/jb/vim.log
endif
if !exists("g:Jb_browser")
    let g:Jb_browser = 'brave-browser'
endif
if !exists("g:Jb_tmpfname")
    let g:Jb_tmpfname = '/tmp/jb.tmp'
endif

" JbAtom
fun! JbLeft(str, needle) " JbLeft('HelloWorld','W') -> 'Hello'
    let l:left = stridx(a:str, a:needle)
    if l:left == -1 " is needle is missing, the whole string is returned.
        return a:str
    endif
    return a:str[l:left:]
endfun

fun! JbRight(str, needle) " JbRight('HelloWorld','W') -> 'orld'
    let l:right = stridx(a:str, a:needle)
    if l:right == -1 " is needle is missing, the whole string is returned.
        return a:str
    endif
    let l:right = l:right + strlen(a:needle)
    return a:str[l:right:]
endfun

fun! JbFromTo(str, from, to) " JbFromTo('HelloWorld','e','o') -> 'll'
    let l:str = JbRight(a:str, a:from)
    return JbLeft(l:str, a:to)
endfun

fun! JbExpandArg(arg, expand) " replace argument, if missing
    " this is used, when calling a function with an empty argument or '.' as
    " arg. The argument is replaced by the <cword>, <cWORD>, <cfile> or with
    " the current line when expand is '.'.
    " eg JbExpand('', '<cword>') returns the word at the cursor position.
    " This helps to programm a shortcut.
    let l:arg=a:arg
    if (l:arg == '') || (l:arg=='.')
        if a:expand == '<cline>'
            let l:arg = getline('.')
        else
            let l:arg=expand(a:expand)
        endif
    endif
    return l:arg
endfun

fun! JbFilter(arr, needle) " easier notation to filter lines that contain needle
    let l:needle='\c'.a:needle
    return filter(a:arr,'match(v:val,l:needle) > -1')
endfun

fun! JbFileFilter(fname, needle)  " read file, but only lines containing needle
    return JbFilter(readfile(a:fname),a:needle)
endfun

fun! JbOneLog(logfname, needle) " array of recent saved files
    let l:arr = JbFileFilter(a:logfname, a:needle)
    let l:arr = map(l:arr, 'matchstr(v:val,"/.*")')  " only the filename in the line
    let l:arr = reverse(l:arr) " we want the newest files at start
    let l:arr = uniq(l:arr) " files are duplicate as they are logged on every write
    " let l:uniqarr = [] " uniq works on sorted lists, ours shall not be sorted
    let l:uniqarr = JbUniq(l:arr) " our own uniq function
    call add(l:uniqarr,'EOF') " rg seems to need an extra line at the end
    call writefile(l:uniqarr, g:Jb_tmpfname) " tmp-file as source for fzf
    return l:uniqarr
endfun

fun! JbUniq(arr) " uniq of arr, even if it is not sorted
    let l:uniqarr = []
    for line in a:arr
        if index(l:uniqarr, line) == -1
            call add(l:uniqarr,line)
        endif
    endfor
    return l:uniqarr
endfun

" Logic Start ------------------------------------------------------------------

func! JbVimlogWrite() " write current filename to permanent logfile
    " We need this file as source where to grep for information
    let txt = hostname() . strftime(" %Y-%m-%d %H:%M:%S ") . expand('%:p')
    call writefile([txt], g:Jb_logfname, 'a')
endfunc
autocmd! BufWritePost * call JbVimlogWrite()

fun! JbBrows(url) " open url in Browser  Jb
    " open browser with url as the argument or the current line if url is '.' or ''
    let l:url = JbExpandArg(a:url,'<cline>')
    if strIdx(l:url,'http') == -1 "
        let l:url = 'https://' . l:url
    else
        let l:url = matchstr(l:url,'http[a-z0-9#.:\/?=_-]*')
    endif
    echo l:url
    silent exec "!".g.Jb_browser." '".l:url."'"
endfun
" :Jb https://google.com
" :call JbBrows('https://google.com')
" :Jb .  opens the browser with the current line as link

fun! JbFzEdit(fileAndAnchor) " edit first matching file in vimlog (and find #anchor) Je
    let l:fileAndAnchor = JbExpandArg(a:fileAndAnchor,'<cfile>').'#.#'
    let l:parts = split(l:fileAndAnchor,'#')
    let l:fneedle = parts[0]
    if l:fneedle == '.'
        let l:fneedle = ''
    endif
    let l:needle = parts[1]
    call JbOneLog(g:Jb_logfname, l:fneedle) " file 
    if l:needle == '.'
        let l:anzahl = ' -m 1'
    else
        let l:anzahl = ''
    endif
    let rgcmd =  'xargs -a '.g:Jb_tmpfname.' rg '.l:anzahl.' --column --line-number --no-heading --color=always --smart-case -- '.shellescape(l:needle)
    echo rgcmd
    call fzf#vim#grep(rgcmd, 1,fzf#vim#with_preview(), 0)
endfun
" :Je night             files containing "night"
" :Je night#alpenglow   grep "alpenglow" in files containing "night"
" :Je .#alpenglow       grep "alpenglow" in all edited files
" :Je .                 use cursorword als search element as in the lines above
" <space>e              same as ":Je ."

fun! JbFzLink(needle) " list matching Md-links, call Browser with selection Jb
    let l:needle = JbExpandArg(a:needle,'<cfile>')
    let l:needle = JbRight(l:needle,'#')
    let l:arr = JbFileFilter(g:Jb_Linkfname, l:needle)
    let l:arr = JbFilter(l:arr,'](') " only lines with markdown-links
    call fzf#run({'source':l:arr, 
                \ 'down':'50%',
                \ 'sink':function('JbBrows')})
endfun
" :Jl junegunn   list markdown links containing "junegunn"
" :Jl .          list markdown links containing the cursorword
" <space>l       same as ":Jl ."

command! -nargs=1 Jb call JbBrows(<f-args>)
command! -nargs=1 Je call JbFzEdit(<f-args>)
command! -nargs=1 Jl call JbFzLink(<f-args>)
nnoremap <leader>jb :call JbBrows('')<cr>
nnoremap <leader>je :call JbFzEdit('')<cr>
nnoremap <leader>jl :call JbFzLink('')<cr>
nnoremap <space>b   :call JbFzBrows('')<cr>
nnoremap <space>e   :call JbFzEdit('')<cr>
nnoremap <space>l   :call JbFzLink('')<cr> 
" shortcut for saving this file and reread it
nnoremap <space>y  :w<cr>:source init.vim<cr>
" :Jl Peterson    show list of markdown links with Peterson and open in Browser
" :Je vetapi      all files, containing 'vetapi'
" :Je qlib#fromTo grep in 'qlib'-files for 'fromTo'
" :Je .#notify    grep 'notify' in all files
"
" # Bookmarks for edited files

" vim.log gets a line for every writing of a file

" JbEdit uses the vim.log to find matching files and fzf to find text inside those
" files. You type ":Je init.vim#fzf" and you will be shown your vimrc and the
" positions of the string fzf. 

" You could also write a bookmark in an arbitrary file and link to "init.vim#fzf" 
" by putting your cursor on that text and start the function with ":Je ." or
" <leader>je.

" The bookmark has two parts. The first part is a search expression for the file
" The second part is the text, that is search in these files. If you use a dot for
" one part, it is a wild card for all. ".#matrix" searches for matrix in all the 
" files. "matrix#." lists the first line of all files. You can omit the following
" "#.". "matrix" shows all files containing matrix in filename or path.

" The workflow is similar to google the web, exept the database are all your edited
" files.

" I don't use the shada file of vim with the history of all visited files,
" because this also has all files I only have read.
" Maybe this could be an extra function. I would increase the amount of remembered
" files with "set viminfo='100,<50,s10,h" to get a list of theses files in 
" vimscript you can use v:oldfiles.

" # Bookmarks for WWW in markdown.

" The plugin assumes, you put all interesting Internetsites in a Markdownfile
" You type ":Jl junegunn" and will see all your bookmarks, that contain junegunn
" in the url or the text to this url on the same line. With <cr> you start
" browsing this website.

" # Dependencies
"
" vim plugin .#junegunn/fzf
" shell programm .#ripgrep

" TODO: I would like to save all my visited websites and store the information,
" that I have read. Maybe a screenreader could help, not reading but writing 
" the text-Information of the website. I am testing a plugin, that scrape markdown
" from a website.
" I would like to have the subtitles of all youtube videos, that I have seen.
" TODO: enaple cnext cprev to jump from on occasion to another
" Jbhesel end ------------------------------------------------------------------

