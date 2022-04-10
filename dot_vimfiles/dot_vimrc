let g:MYVIMRC = expand('<sfile>')

let thisDir = resolve(fnamemodify(MYVIMRC, ':h'))
for i in ['plugins', 'theme', 'settings', 'maps', 'auto']
    let scriptPath = globpath(thisDir, i . '.vim')
    if filereadable(scriptPath)
        exec ('source ' . scriptPath)
    endif
endfor
