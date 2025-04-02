
" Get the directory of the current script file
let s:script_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')

" Append 'json.sh' to the directory path
let s:json_sh_path = s:script_dir . '/json.sh'


function! GetSuff()
    let current_line = line('.')
    let current_col = col('.')
    let all_lines = getbufline('%', 1, '$')
    
    
    " Get all text after cursor
    let after_current_line = strpart(all_lines[current_line-1], current_col-1)
    let after_lines = all_lines[(current_line):]  " Lines after current line
    let text_after = join([after_current_line] + after_lines, "\\n")
    return text_after
endfunction 

function! GetPre()
    let current_line = line('.')
    let current_col = col('.')
    let all_lines = getbufline('%', 1, '$')
    
    " Get all text before cursor
    let before_lines = all_lines[0:(current_line-2)]  " Lines before current line
    let before_current_line = strpart(all_lines[current_line-1], 0, current_col-1)
    let text_before = join(before_lines + [before_current_line], "\\n")

    return text_before
endfunction 


" Function to POST to Ollama API and insert the response
function! FetchOllamaResponse() abort
  " API endpoint and JSON payload
  let url = 'http://localhost:11434/api/generate'
  let json_data = '{     "model": "qwen2.5-coder:0.5b",    "prompt": "<|fim_prefix|>' . GetPre() . '<|fim_suffix|>' .GetSuff() . '<|fim_middle|>", "stream": false, "raw" : true }'



  " Construct the curl command with proper JSON handling
  let command = 'curl -s -X POST ' .
        \ '-H "Content-Type: application/json" ' .
        \ '-d ' . shellescape(json_data) . ' ' .
        \ shellescape(url) .
	\ ' |' . s:json_sh_path  .
 	\ ' | sed  "s/\\\\n/\n/g"'


  " Execute and capture the response
 let response = system(command)

  " Check if we got a valid response
  if v:shell_error != 0 || empty(response)
    echohl ErrorMsg
    echo "Failed to get response from Ollama API"
    echohl None
    return ''
  endif

  return response
endfunction


" Define the highlight group for low opacity text
highlight TempHello guifg=#cccccc gui=italic ctermfg=gray

" The main function that handles the temporary insertion
function! InsertTemporaryHello()
    let ollamaResponse = FetchOllamaResponse()
    if empty(ollamaResponse)
        return
    endif

    " Save the current cursor position and line content
    let s:original_line = line('.')
    let s:original_col = col('.')
    let s:original_lines = getline(1, '$')  " Save entire buffer state

    " Split the response into lines
    let response_lines = split(ollamaResponse, "\n", 1)

    " Get the current line content
    let current_line = getline('.')

    " Handle first line (modified current line)
    let before_cursor = strpart(current_line, 0, s:original_col - 1)
    let after_cursor = strpart(current_line, s:original_col - 1)
    let modified_lines = [before_cursor . response_lines[0]]

    " Add middle lines (if any)
    if len(response_lines) > 1
        call extend(modified_lines, response_lines[1:-2])
    endif

    " Handle last line (if multiline)
    if len(response_lines) > 1
        let last_line = response_lines[-1] . after_cursor
        call add(modified_lines, last_line)
    else
        " Single line case
        let modified_lines[0] .= after_cursor
    endif

    " Replace current line and add new lines if needed
    call setline(s:original_line, modified_lines[0])
    if len(modified_lines) > 1
        call append(s:original_line, modified_lines[1:])
    endif

    " Calculate highlight positions
    let s:hl_start = s:original_col
    let s:hl_end = len(modified_lines[0]) - len(after_cursor)
    let s:hl_lines = len(modified_lines)

    " Highlight all affected lines
    for i in range(s:hl_lines)
        if i == 0  " First line
            call matchaddpos('TempHello', [[s:original_line + i, s:hl_start, s:hl_end]])
        elseif i == s:hl_lines - 1  " Last line
            call matchaddpos('TempHello', [[s:original_line + i, 1, len(modified_lines[i])]])
        else  " Middle lines
            call matchaddpos('TempHello', [[s:original_line + i]])
        endif
    endfor

    " Set up key mappings to handle acceptance or rejection
    nnoremap <buffer> <silent> <Tab> :call AcceptHello()<CR>
    nnoremap <buffer> <silent> <Esc> :call RejectHello()<CR>
    nnoremap <buffer> <silent> <CR> :call RejectHello()<CR>
    
    inoremap <buffer> <silent> <Tab> <Esc>:call AcceptHello()<CR>a
    inoremap <buffer> <silent> <Esc> <Esc>:call RejectHello()<CR>a
endfunction

function! AcceptHello()
    " Clean up
    call clearmatches()
    silent! iunmap <buffer> <Tab>
    silent! iunmap <buffer> <Esc>
    silent! nunmap <buffer> <Tab>
    silent! nunmap <buffer> <Esc>
    silent! nunmap <buffer> <CR>
endfunction

function! RejectHello()
    " Restore original text
    let current_line = line('.')
    let num_lines = len(getline(1, '$'))
    let num_original = len(s:original_lines)

    " If we added lines, delete the extra ones
    if num_lines > num_original
        execute (num_original + 1) .',$delete'
    endif

    " Restore original content
    for i in range(len(s:original_lines))
        call setline(i + 1, s:original_lines[i])
    endfor

    " Clean up
    call clearmatches()
    silent! iunmap <buffer> <Tab>
    silent! iunmap <buffer> <Esc>
    silent! nunmap <buffer> <Tab>
    silent! nunmap <buffer> <Esc>
    silent! nunmap <buffer> <CR>
endfunction

" Map Ctrl+L in insert mode to trigger the suggestion
inoremap <silent> <C-L> <C-O>:call InsertTemporaryHello()<CR>
