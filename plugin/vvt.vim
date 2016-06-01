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
    let l:ret = a:string
    let l:ret = substitute(l:ret,'\%x5C','\\\\','g')
    let l:ret = substitute(l:ret,'\%x22','\\"','g')
    let l:ret = substitute(l:ret,'\%x2F','/','g')
    let l:ret = substitute(l:ret,'\%x08','\\b','g')
    let l:ret = substitute(l:ret,'\%x0C','\\f','g')
    let l:ret = substitute(l:ret,'\%x0A','\\n','g')
    let l:ret = substitute(l:ret,'\%x0D','\\r','g')
    let l:ret = substitute(l:ret,'\%x09','\\t','g')
    return l:ret
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
    let l:content = join(getline(a:line1, a:line2), "\n")
    let l:data = printf(
                \ '{"code":"%s","language":"%s","time":2}',
                \ s:JSONEncode(l:content),
                \ s:parser(&filetype))

    let l:url = s:post('https://vvt.nu/api/pastebin.json', l:data)
    call s:finished(l:url)
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

    let l:cmd = substitute(g:vvt_browser_command, '%URL%', a:url, 'g')

    if l:cmd =~# '^!'
        silent! exec l:cmd
    elseif l:cmd =~? '^:[A-Z]'
        exec l:cmd
    else
        call system(l:cmd)
    endif
endfunction

function! s:post(url, data)
    let l:res = ''
python << endpython
import vim
import urllib3
import certifi

postdata = vim.eval('a:data')
url = vim.eval('a:url')

headers = {
    'User-Agent':   'vvt.vim/1.0',
    'Content-Type': 'application/json',
    'Connection':   'keep-alive'
}

http = urllib3.PoolManager(
    10,
    headers=headers,
    cert_reqs='CERT_REQUIRED',
    ca_certs=certifi.where()
)

try:
    res = http.request('POST', url, body=postdata)
    vim.command('let l:res = "' + res.data + '"')
except urllib3.exceptions.HTTPError, e:
    vim.command('echoerr "vvt.nu" "' + str(e.code) + ": " + e.reason + '"')
endpython
    return l:res
endfunction

function! GetVVT(url)
    let l:id = substitute(a:url, '^https\:\/\/vvt.nu\/','\1','')
    let l:code = []
    let l:ft = ''
    let l:fn = ''

    let l:file = tempname() . l:fn
python << endpython
import vim
import urllib3
import json
import certifi

id = vim.eval('id')
file = vim.eval('file')

url = 'https://vvt.nu/' + id + '.json'

headers = {
    'User-Agent':   'vvt.vim/1.0',
    'Content-Type': 'application/json',
    'Connection':   'keep-alive'
}

http = urllib3.PoolManager(
    10,
    headers=headers,
    cert_reqs='CERT_REQUIRED',
    ca_certs=certifi.where()
)

try:
    res = http.request('GET', url)
    data = json.loads(res.data)

    f = open(file, 'wb')
    f.write(data['code'])
    f.close()

    vim.command('let l:ft = "' + data['language'] + '"')
    vim.command('let l:fn = "' + data['slug'] + '"')
except urllib3.exceptions.HTTPError, e:
    vim.command('echoerr "vvt.nu" "' + str(e.code) + ": " + e.reason + '"')
endpython

    if l:ft ==# 'c_cpp'
        let l:ft='cpp'
    endif

    execute 'edit ' . l:file
    exec 'set filetype=' . l:ft
endfunction

command! -nargs=? -range=% VVTPaste :call VVT(<line1>, <line2>)
command! -nargs=* VVTGet :call GetVVT(<f-args>)

let g:loaded_vvt=2
