" author: vvt.nu - c0r73x
" email: c0r73x@gmail.com
"
" .vimrc
" vvt_use_browser  *optional
" vvt_browser_command  *optional
" --------------------------------
" Example
" let g:vvt_use_browser = 1
" let g:vvt_browser_command = 'echo "%URL%" | xclip'
" --------------------------------

if exists('g:loaded_vvt')
    finish
endif
let g:loaded_vvt=1

function! s:JSONEncode(string)
    let ret = a:string
    let ret = substitute(ret,'\%x5C','\\\\','g')
    let ret = substitute(ret,'\%x22','\\"','g')
    let ret = substitute(ret,'\%x2F','/','g')
    let ret = substitute(ret,'\%x08','\\b','g')
    let ret = substitute(ret,'\%x0C','\\f','g')
    let ret = substitute(ret,'\%x0A','\\n','g')
    let ret = substitute(ret,'\%x0D','\\r','g')
    let ret = substitute(ret,'\%x09','\\t','g')
    return ret
endfunction

if exists('g:vvt_use_browser')
    if g:vvt_use_browser == 1
        if !exists('g:vvt_browser_command')
            if exists(':OpenBrowser')
                let g:vvt_browser_command = ':OpenBrowser %URL%'
            elseif has('win32')
                let g:vvt_browser_command = 
                            \ '!start rundll32 url.dll,FileProtocolHandler %URL%'
            elseif has('mac')
                let g:vvt_browser_command = 'open %URL%'
            elseif executable('xdg-open')
                let g:vvt_browser_command = 'xdg-open %URL%'
            else
                if has('unix')
                    if system('uname') =~# 'Darwin'
                        let g:vvt_browser_command = 'open %URL%'
                    else
                        let g:vvt_browser_command = 'dwb %URL% &'
                    end
                else
                endif
            endif
        endif
    endif
endif

function! VVT(line1, line2)
    let content = join(getline(a:line1, a:line2), "\n")
    let data = printf(
                \ '{"code":"%s","language":"%s","time":2}',
                \ s:JSONEncode(content),
                \ s:parser(&ft))

    let url = s:post('https://vvt.nu/api/pastebin.json', data)
    call s:finished(url)
endfunction

function! s:parser(type)
    if a:type ==# ''
        return 'text'
    elseif a:type ==# 'eruby'
        return 'ruby'
    elseif a:type ==# 'zsh' || a:type ==# 'bash'
        return 'sh'
    elseif a:type ==# 'cpp' || a:type ==# 'c'
        return 'c_cpp'
    else
        return a:type
    endif
endfunction

function! s:finished(url)
    if a:url !~? '^https.*'
        echoerr 'vvt.nu' 'Incorrect return type!'
        return
    else
        echom a:url
    endif

    if ! exists('g:loaded_vvt') || !exists('g:vvt_browser_command')
        return
    endif

    let cmd = substitute(g:vvt_browser_command, '%URL%', a:url, 'g')

    if cmd =~# '^!'
        silent! exec cmd
    elseif cmd =~? '^:[A-Z]'
        exec cmd
    else
        call system(cmd)
    endif
endfunction

function! s:post(url, data)
    let res = ''
python << endpython
import vim
import urllib2

postdata = vim.eval('a:data')
url = vim.eval('a:url')

req = urllib2.Request(url)
req.add_header('User-Agent', 'vvt.vim/1.0')
req.add_header('Content-Type', 'application/json')
req.add_header('Connection', 'keep-alive')

try:
    res = urllib2.urlopen(req, postdata)
    vim.command('let res = "' + res.read() + '"')
except urllib2.HTTPError, e:
    vim.command('echoerr "vvt.nu" "' + str(e.code) + ": " + e.reason + '"')
endpython
    return res
endfunction

function! GetVVT(url)
    let id = substitute(a:url, '^https\:\/\/vvt.nu\/','\1','')
    let code = []
    let ft = ''
    let fn = ''

python << endpython
import vim
import urllib2
import json

id = vim.eval('id')
url = 'https://vvt.nu/' + id + '.json'

req = urllib2.Request(url)
req.add_header('User-Agent', 'vvt.vim/1.0')
req.add_header('Accept', 'application/json')
req.add_header('Connection', 'keep-alive')

try:
    res = urllib2.urlopen(req)
    data = json.loads(res.read())

    vim.command('let code = split("' + data['code'] + '", "\n")')
    vim.command('let ft = "' + data['language'] + '"')
    vim.command('let fn = "' + data['slug'] + '"')
except urllib2.HTTPError, e:
    vim.command('echoerr "vvt.nu" "' + str(e.code) + ": " + e.reason + '"')
endpython

    if ft ==# 'c_cpp'
        let ft='cpp'
    endif

    let file = tempname().fn
    call writefile(code,file,'b')
    execute 'edit '.file
    exec 'set filetype='.ft
endfunction

command! -nargs=? -range=% VVTPaste :call VVT(<line1>, <line2>)
command! -nargs=* VVTGet :call GetVVT(<f-args>)

let g:loaded_vvt=2
