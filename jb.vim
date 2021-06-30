" Jb vimscript Plugin --see vimscript.md --------------------------------------------------------------------
" global Variables  
let g:Jb_logfname = get(g:, 'Jb_logfname', '/home/'.$USER.'/vim.log') "eg /home/jb/vim.log
let g:Jb_browser = get(g:, 'Jb_browser', 'brave-browser')
let g:Jb_tmpfname = get(g:, 'Jb_tmpfname', '/tmp/jb.tmp')

" some helper functions ------------------------------------------

fun! JbLeft(str, needle) " JbLeft('HelloWorld','W') -> 'Hello'
    let l:left = stridx(a:str, a:needle)
    if l:left == -1 " is needle is missing, the whole string is returned.
        return a:str
    endif
    let l:left = l:left-1
    return a:str[:l:left]
endfun

fun! JbRight(str, needle) " JbRight('HelloWorld','W') -> 'orld'
    let l:right = stridx(a:str, a:needle)
    if l:right == -1 " is needle is missing, the whole string is returned.
        return a:str
    endif
    let l:right = l:right + strlen(a:needle)
    return a:str[l:right:]
endfun

fun! JbExpandArg(arg, expand) " replace argument, if missing
    " this is used, when calling a function with an empty argument or '.' as
    " arg. The argument is replaced by the <cword>, <cWORD>, <cfile> or with
    " the current line when expand is '<cline>'.
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

fun! JbUniq(arr) " uniq of arr, even if it is not sorted
    let l:uniqarr = []
    for line in a:arr
        if index(l:uniqarr, line) == -1
            call add(l:uniqarr,line)
        endif
    endfor
    return l:uniqarr
endfun

fun! JbFilter(arr, needle) " easier notation to filter lines that contain needle
    let l:needle='\c'.a:needle
    return filter(a:arr,'match(v:val,l:needle) > -1')
endfun

fun! JbFileFilter(fname, needle)  " read file, but only lines containing needle
    return JbFilter(readfile(a:fname),a:needle)
endfun

" Logic Start ------------------------------------------------------------------

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

func! JbVimlogWrite() " write current filename to permanent logfile
    " We need this file as source where to grep for information
    let txt = hostname() . strftime(" %Y-%m-%d %H:%M:%S ") . expand('%:p')
    call writefile([txt], g:Jb_logfname, 'a')
endfunc
autocmd! BufWritePost * call JbVimlogWrite()

fun! JbBrows(url) " open url in Browser  Jb
    " open browser with url as the argument or the current line if url is '.' or ''
    let l:url = JbExpandArg(a:url,'<cline>')
    if stridx(l:url,'http') == -1 "
        let l:url = 'https://' . l:url
    else
        let l:url = matchstr(l:url,'http[a-z0-9#.:\/?=_-]*')
    endif
    echo l:url
    silent exec "!".g:Jb_browser." '".l:url."'"
endfun
" :Jb https://heise.de
" :Jb heise.de           # opens https://heise.de
" :Jb . #  opens the browser with the current line as link starting from http...

fun! JbFzEdit(fileAndAnchor) " edit first matching file in vimlog (and find #anchor) Je
    let l:fileAndAnchor = JbExpandArg(a:fileAndAnchor,'<cfile>')
    if stridx(l:fileAndAnchor,'#') is -1
        let l:fileneedle = ''
        let l:needle = l:fileAndAnchor
        if stridx(l:needle, '.') >= 0   " search for filename
            let l:fileneedle = l:needle
            let l:needle = '.'
        endif
    else
        let l:fileneedle = JbLeft(l:fileAndAnchor, '#')
        let l:needle = JbRight(l:fileAndAnchor,'#')
    endif
    let l:fileArr = JbOneLog(g:Jb_logfname, l:fileneedle) " file 
    if len(l:fileArr) is 1 " no file matched, only EOF
        let l:fileArr = JbOneLog(g:Jb_logfname, '') " search in all files
        if l:needle == '.'
            let l:needle = l:fileneedle
        endif
    endif
    if l:needle == '.' " This would match all lines
        let l:anzahl = ' -m 1' " rg match only first line in file
    else
        let l:anzahl = ''
    endif
    let rgcmd =  'xargs -a '.g:Jb_tmpfname.' rg '.l:anzahl.' --column --line-number --no-heading --color=always --smart-case -- '.shellescape(l:needle)
    echo "JbFzEdit ".l:fileneedle.' '.l:needle
    call fzf#vim#grep(rgcmd, 1,fzf#vim#with_preview(), 0)
endfun
" :Je night#alpenglow   grep "alpenglow" in files containing "night"
" :Je .#alpenglow       grep "alpenglow" in all edited files
" :Je alpenglow         grep "alpenglow" in all edited files
" :Je nightwish.md      search for files with names containing "nightwish.md"
" :Je .#nightwish.md    search for "nightwish.md" in all edited files
" :Je .                 use cursorword als search element as in the lines above

fun! JbFzLink(needle) " list Md-links  :Jl
    let l:needle = JbExpandArg(a:needle,'<cfile>')
    if stridx(l:needle,'#') == -1
        let l:fileneedle = '.'   " or '.md' ?
    else
        let l:fileneedle = JbLeft(l:needle,'#')
    endif
    let l:needle = JbRight(l:needle,'#')
    let l:needle = ']\(h.*'.l:needle.'|'.l:needle.']\(h'  " needle and md-link
    let l:fileArr = JbOneLog(g:Jb_logfname, l:fileneedle)
    let l:rgcmd =  'xargs -a '.g:Jb_tmpfname.' rg --line-number --no-heading --smart-case -- '.shellescape(l:needle)
    echo l:rgcmd
    let l:arr = systemlist(l:rgcmd)
    let l:arr = JbFilter(l:arr, '[')
    call fzf#run({'source':l:arr, 
                \ 'down':'50%',
                \ 'sink':function('JbBrows')})
endfun
" :Jl junegunn   list markdown links containing "junegunn"
" :Jl .          list markdown links containing the cursorword


command! -nargs=1 Jb call JbBrows(<f-args>)
command! -nargs=1 Je call JbFzEdit(<f-args>)
command! -nargs=1 Jl call JbFzLink(<f-args>)
nnoremap <leader>jb :call JbBrows('')<cr>
nnoremap <leader>je :call JbFzEdit('')<cr>
nnoremap <leader>jl :call JbFzLink('')<cr>
" Jbhesel end ------------------------------------------------------------------

