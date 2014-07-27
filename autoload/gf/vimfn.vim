scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:NS = tolower(expand('<sfile>:t:r'))
let s:FUNCTYPE = {
\   'AUTOLOAD' : 1,
\   'GLOBAL'   : 2,
\   'LOCAL'    : 3,
\   'SCRIPT'   : 4,
\}

function! s:_getVar(var)
    if has_key(s:, a:var)
        return s:[a:var]
    else
        throw a:var . ' is not exists'
    endif
endfunction

function! s:getOutPutText(cmd)
    redir => result
    silent exe a:cmd
    redir END
    return result
endfunction

function! s:funcType(fn)
    let fn = a:fn
    let _ = s:FUNCTYPE
    let prefix = fn[:1]
    if prefix ==# 'l:' && !empty(fn[2])
        return _.LOCAL
    endif
    if prefix ==# 'g:' && fn[2] =~# '\v\C[A-Z]'
        return _.GLOBAL
    endif
    if prefix ==# 's:' && !empty(fn[2])
        return _.SCRIPT
    endif
    if fn =~ '\v^\c\<sid\>'
        return _.SCRIPT
    endif
    if fn =~ '\v\C^[A-Z][a-zA-Z0-9_]*$'
        return _.GLOBAL
    endif
    if fn =~ '\v\a+#\a'
        return _.AUTOLOAD
    endif
    return 0
endfunction

function! s:aFnToPath(afn)
    let t = join(split(a:afn, '#')[:-2], '/') . '.vim'
    return ['autoload/' . t, 'plugin/' . t]
endfunction

function! s:findPath(type, fn)
    let fn = a:fn
    let type = a:type
    let _ = s:FUNCTYPE
    if type is _.AUTOLOAD
        let t = filter(map(s:aFnToPath(fn), 'globpath(&rtp, v:val)'), '!empty(v:val)')
        return empty(t) ? '' : split(t[0], '\v\r\n|\n')[0]
    elseif type is _.GLOBAL
        return matchstr(split(s:getOutPutText('1verbose function ' . fn), '\v\r\n|\n')[1], '\v\f+$')
    elseif type is _.LOCAL
        return '%'
    elseif type is _.SCRIPT
        return '%'
    endif
endfunction

function! s:getFnPos(path, fn)
    let reg = '\v\C^\s*fu%[nction\!]\s+' . a:fn . '\s*\('
    let isbuf = a:path is '%'
    let lines = isbuf ? getline(1, '$') : readfile(a:path)
    let line = len(lines)

    while line
        let line -= 1
        let col = match(lines[line], reg) + 1
        if col
            return {'line' : line + 1, 'col' : col}
        endif
    endwhile
    return isbuf ? 0 : {'line' : 1, 'col' : 1}
endfunction

function! s:cfile()
    try
        let saveisf = &isf
        if match(&isf, '\v\<') is -1
            set isf+=<
        endif
        if match(&isf, '\v\>') is -1
            set isf+=>
        endif
        let ret = expand('<cfile>')
    finally
        let &isf = saveisf
    endtry
    return ret
endfunction

function! s:pickFname(str)
    return matchstr(a:str, '\v(\c\<sid\>)?[a-zA-Z0-9#_:]+')
endfunction

function! s:pickUp()
    return s:pickFname(s:cfile())
endfunction

function! s:SID(...)
    let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
    return a:0 < 1 ? id : id . a:1
endfunction

function! s:find(str)
    let fn = s:pickFname(a:str)
    let fnt = s:funcType(fn)
    if fnt is 0
        return 0
    endif
    let path = s:findPath(fnt, fn)
    if fnt is s:FUNCTYPE.SCRIPT
        let fn = substitute(fn, '\v\c(s:|\<sid\>)', '\\c(s:|\\<sid\\>)\\C', '')
        "echoe fn
    endif
    let pos = s:getFnPos(path, fn)
    if path is '%'
        if pos is 0
            return 0
        else
            let path = expand(path)
        endif
    endif
    return extend({'path' : path}, pos)
endfunction

function! gf#{s:NS}#sid(...)
    return call(function('s:SID'), a:000)
endfunction

function! gf#{s:NS}#find()
    return s:find(s:pickUp())
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim:set et sts=4 ts=4 sw=4: