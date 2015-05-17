" mark/cascade.vim: Cascading search through all used mark groups.
"
" DEPENDENCIES:
"   - mark.vim autoload script
"
" Copyright: (C) 2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" Version:     2.9.0
" Changes:
" 16-May-2015, Ingo Karkat
" - Move functions for cascading search into seperate autoload script.

let [s:cascadingLocation, s:cascadingPosition, s:cascadingGroupIndex, s:cascadingStop] = [[], [], -1, -1]
function! s:GetLocation()
	return [tabpagenr(), winnr(), bufnr('')]
endfunction
function! s:SetCascade()
	let s:cascadingLocation = s:GetLocation()
	let [l:markText, s:cascadingPosition, s:cascadingGroupIndex] = mark#CurrentMark()
endfunction
function! mark#cascade#Start( count, isStopBeforeCascade )
	" Try passed mark group, current mark, last search, first used mark group, in that order.

	if ! a:count
		call s:SetCascade()
		if s:cascadingGroupIndex != -1
			" We're already on a mark. Take that as the start and proceed to
			" then next match already.
			return mark#cascade#Next(1, a:isStopBeforeCascade, 0)
		endif
	endif

	" Search for next mark and start cascaded search there.
	if ! mark#SearchGroupMark(a:count, 1, 0, 1)
		if a:count
			return 0
		elseif ! mark#SearchGroupMark(mark#NextUsedGroupIndex(0, 0, -1, 1) + 1, 1, 0, 1)
			call mark#NoMarkErrorMessage()
			return 0
		endif
	endif
	call s:SetCascade()
	return 1
endfunction
function! mark#cascade#Next( count, isStopBeforeCascade, isBackward )
	if s:cascadingGroupIndex == -1
		call mark#ErrorMsg('No cascaded search defined')
		return 0
	elseif s:cascadingStop != -1
		if s:cascadingLocation == s:GetLocation()
			" Within the same location: Switch to the next mark group.
			let s:cascadingGroupIndex = s:cascadingStop
		else
			" Allow to continue searching for the current mark group in other
			" locations.
		endif
		let s:cascadingStop = -1
		let [s:cascadingLocation, s:cascadingPosition] = [[], []]   " Clear so that the next mark match will re-initialize them with the base match for the new mark group.
	endif

	let l:save_wrapscan = &wrapscan
	set wrapscan
	let l:save_view = winsaveview()
	try
		if ! mark#SearchGroupMark(s:cascadingGroupIndex + 1, a:count, a:isBackward, 1)
			return s:Cascade(a:count, a:isStopBeforeCascade, a:isBackward)
		endif
		if s:cascadingLocation == s:GetLocation()
			if s:cascadingPosition == getpos('.')[1:2]
				" We're returned to the first match from that group. Undo that
				" last jump, and then cascade to the next one.
				call winrestview(l:save_view)
				return s:Cascade(a:count, a:isStopBeforeCascade, a:isBackward)
			endif
		endif

		if empty(s:cascadingLocation) && empty(s:cascadingPosition)
			call s:SetCascade()
		endif

		return 1
	finally
		let &wrapscan = l:save_wrapscan
	endtry
endfunction
function! s:Cascade( count, isStopBeforeCascade, isBackward )
	let l:nextGroupIndex = mark#NextUsedGroupIndex(a:isBackward, 0, s:cascadingGroupIndex, 1)
	if l:nextGroupIndex == -1
		redraw  " Get rid of the previous mark search message.
		call mark#ErrorMsg(printf('Cascaded search ended with %s used group', (a:isBackward ? 'first' : 'last')))
		return 0
	endif

	if a:isStopBeforeCascade
		let s:cascadingStop = l:nextGroupIndex
		redraw  " Get rid of the previous mark search message.
		call mark#WarningMsg('Cascaded search reached last match of current group')
		return 1
	else
		let s:cascadingGroupIndex = l:nextGroupIndex
		let [s:cascadingLocation, s:cascadingPosition] = [[], []]   " Clear so that the next mark match will re-initialize them with the base match for the new mark group.
		return mark#cascade#Next(a:count, a:isStopBeforeCascade, a:isBackward)
	endif
endfunction

" vim: ts=4 sts=0 sw=4 noet
