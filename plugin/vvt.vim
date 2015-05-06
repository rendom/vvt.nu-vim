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
                \ '{"code":"%s","language":"%s"}',
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
    if a:url !~? '.*https.*'
        echoerr 'vvt.nu' s:jsonValue(a:url,'response')
        return
    endif
    echo a:url
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
    let file = tempname()
    call writefile([a:data], file)
    let quote = &shellxquote ==# '"' ?    "'" : '"'
    let header = '-H "Content-Type:application/json"'
    let res = system('curl '.header.' -s -d @'.quote.file.quote.' '.a:url)
    call delete(file)
    return res
endfunction

function! s:jsonValue(string, val)
    let ret=''
perl << EOF
    my $string = VIM::Eval('a:string');
    my $val = VIM::Eval('a:val');

    @res = $string =~ /"$val":\s*"((?:(?!,").)*)"(,|})/;
    VIM::DoCommand("let ret=\"$res[0]\"");
EOF
    return ret
endfunction

function! GetVVT(url)
    let id = substitute(a:url, '^https\:\/\/vvt.nu\/','\1','')
    let res = system('curl -s https://vvt.nu/'.id.'.json')
    let code = split(s:jsonValue(res,'code'),"\n")
    let ft = s:jsonValue(res,'language')

    if ft ==# 'c_cpp'
        let ft='cpp'
    endif

    let fn = s:jsonValue(res,'slug')
    let file = tempname().fn
    call writefile(code,file,'b')
    execute 'edit '.file
    exec 'set filetype='.ft
endfunction

command! -nargs=? -range=% VVTPaste :call VVT(<line1>, <line2>)
command! -nargs=* VVTGet :call GetVVT(<f-args>)

let g:loaded_vvt=2
