" Vim filetype plugin file
" Language:      Perl
" Maintainer:    Andy Lester <andy@petdance.com>
" Homepage:      http://github.com/petdance/vim-perl
" Bugs/requests: http://github.com/petdance/vim-perl/issues
" Last Change:   2009-08-14
"
" Modified for my own purposes.

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

""""""""""""""""""""""""""""""""""""""""""
" Ultisnips Dancer support
""""""""""""""""""""""""""""""""""""""""""
fun! s:detectTypeOfPerl()
perl <<EOF
    for( 0..$curbuf->Count ) {
        if ( $curbuf->Get($_) =~ /use Dancer/ ) {
            VIM::DoCommand(':UltiSnipsAddFiletypes dancer');
            return;
        }
    }
EOF
endfun

""""""""""""""""""""""""""""""""""""""""""
" vim ctags stuff
""""""""""""""""""""""""""""""""""""""""""
setlocal iskeyword+=:  " make tags with :: in them useful

let s:BIN = fnamemodify(resolve(expand("<sfile>:p")), ":h")
if ! exists("s:defined_functions")
    if ! exists('g:PT_use_ppi')
        let g:PT_use_ppi = 0
    endif
    function s:init_tags()
        perl <<EOF
            use Cwd;
            my $bin = VIM::Eval('s:BIN');
            require "$bin/fatpacked_perltags.pl" or die "Couldn't find Perl::Tags";
            # PPI is probably not installed
            # And is not fatpackable
            # also slows down vim loading
            my $ppi = VIM::Eval('g:PT_use_ppi');
            if ( $ppi ) {
                require Perl::Tags::PPI;
            }
            my %args = ( max_level => 2 );
            $tagger = Perl::Tags::Hybrid->new(
                %args,
                taggers => [
                    Perl::Tags::Naive::Moose->new(%args),
                    $ppi ? Perl::Tags::PPI->new(%args) : (),
                ]
            );
EOF
    endfunction

    " let vim do the tempfile cleanup and protection
    let s:tagsfile = tempname()

    function s:do_tags(filename)
    perl <<EOF
        my $filename = VIM::Eval('a:filename');
        return if !-f $filename;

        our $tagger;
        $tagger->process(files => $filename, refresh=>1 );

        my $tagsfile=VIM::Eval('s:tagsfile');
        VIM::SetOption("tags+=$tagsfile");

        # of course, it may not even output, for example, if there's nothing new to process
        $tagger->output( outfile => $tagsfile );
EOF
    endfunction

    if has('perl')
        call s:init_tags() " only the first time
    endif

    let s:defined_functions = 1
endif

if has('perl')
    " This only runs for perl, so do it on all new files
    call s:do_tags(expand('%'))
    " Every time the buffer changes, we do the tags
    augroup perltags
        au!
        autocmd BufRead,BufWritePost *.pm,*.pl,*.t call s:do_tags(expand('%'))
    augroup END

    "" Other snippets
    call s:detectTypeOfPerl()
endif


setlocal formatoptions+=crq
setlocal keywordprg=perldoc\ -f

setlocal comments=:#
setlocal commentstring=#%s

" Change the browse dialog on Win32 to show mainly Perl-related files
if has("gui_win32")
    let b:browsefilter = "Perl Source Files (*.pl)\t*.pl\n" .
                       \ "Perl Modules (*.pm)\t*.pm\n" .
                       \ "Perl Documentation Files (*.pod)\t*.pod\n" .
                       \ "All Files (*.*)\t*.*\n"
endif

" Provided by Ned Konz <ned at bike-nomad dot com>
"---------------------------------------------
setlocal include=\\<\\(use\\\|require\\)\\>

" Mangles the string under the cursor so that gf can lookup perl modules
" SteveH: Added a substitution so that gf will work on package::module->new();
setlocal includeexpr=substitute(substitute(substitute(v:fname,'-$','',''),'::','/','g'),'$','.pm','')
setlocal define=[^A-Za-z_]

" The following line changes a global variable but is necessary to make
" gf and similar commands work.  The change to iskeyword was incorrect.
" Thanks to Andrew Pimlott for pointing out the problem. If this causes a
" problem for you, add an after/ftplugin/perl.vim file that contains
"       set isfname-=:
set isfname+=:

" Set this once, globally.
if !exists("perlpath")
    if executable("perl")
      try
        if &shellxquote != '"'
            let perlpath = system('perl -e "print join(q/,/,@INC, q/lib/)"')
        else
            let perlpath = system("perl -e 'print join(q/,/,@INC, q/lib/)'")
        endif
        let perlpath = substitute(perlpath,',.$',',,','')
      catch /E145:/
        let perlpath = ".,,"
      endtry
    else
        " If we can't call perl to get its path, just default to using the
        " current directory and the directory of the current file.
        let perlpath = ".,,"
    endif
endif

let &l:path=perlpath


map <F3> :!perldoc <cfile><CR>
map <F12> :%!perltidy -st -i <C-r>=&ts<CR><CR>
vmap <F12> :!perltidy -st -i <C-r>=&ts<CR><CR>


"---------------------------------------------

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal fo< com< cms< inc< inex< def< isf< kp<" .
            \         " | unlet! b:browsefilter"

" Restore the saved compatibility options.
let &cpo = s:save_cpo

" vim: set ts=4 sw=4 et :
