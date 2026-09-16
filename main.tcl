#!/usr/bin/tclsh

package require Tk

# ------------------------------------------------------------------------------
# Game Configuration & Global State
# ------------------------------------------------------------------------------
set ROWS 10
set COLS 10
set BOMBS 12

set flags_left $BOMBS
set time_elapsed 0
set timer_id ""
set game_over 0
set game_started 0
set revealed_count 0

array set NUM_COLORS {
    1 blue 2 green 3 red 4 darkblue
    5 brown 6 cyan 7 black 8 gray
}

array set board {}
array set state {}
array set btn {}

# ------------------------------------------------------------------------------
# UI Setup
# ------------------------------------------------------------------------------
wm title . "Tk Minesweeper"
wm resizable . 0 0

frame .top -bd 2 -relief ridge
pack .top -fill x -padx 5 -pady 5

label .top.bombs -textvariable flags_left -font {Helvetica 14 bold} -fg red -bg black -width 4
button .top.reset -text "🙂" -font {Helvetica 12} -command reset_game
label .top.timer -textvariable time_elapsed -font {Helvetica 14 bold} -fg red -bg black -width 4

pack .top.bombs -side left -padx 5
pack .top.reset -side top -expand 1
pack .top.timer -side right -padx 5

frame .board -bd 2 -relief ridge
pack .board -padx 5 -pady 5

# ------------------------------------------------------------------------------
# Game Logic
# ------------------------------------------------------------------------------

proc reset_game {} {
    global ROWS COLS BOMBS flags_left time_elapsed timer_id game_over game_started revealed_count board state btn

    if {$timer_id ne ""} {
        after cancel $timer_id
        set timer_id ""
    }

    set flags_left $BOMBS
    set time_elapsed 0
    set game_over 0
    set game_started 0
    set revealed_count 0
    .top.reset configure -text "🙂"

    foreach name [array names btn] {
        destroy $btn($name)
    }
    array unset board
    array unset state
    array unset btn

    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            set board($r,$c) 0
            set state($r,$c) "hidden"
            
            set b [button .board.b_${r}_${c} -width 2 -height 1 \
                    -font {Helvetica 11 bold} -relief raised \
                    -command [list click_cell $r $c]]
            
            # Right-click / Ctrl-click: Toggle Flag
            bind $b <Button-3> [list toggle_flag $r $c]
            bind $b <Control-1> [list toggle_flag $r $c]

            # Middle-click: Chord adjacent cells
            bind $b <Button-2> [list chord_cell $r $c]
            
            grid $b -row $r -column $c
            set btn($r,$c) $b
        }
    }
}

proc place_bombs {safe_r safe_c} {
    global ROWS COLS BOMBS board

    set placed 0
    while {$placed < $BOMBS} {
        set r [expr {int(rand() * $ROWS)}]
        set c [expr {int(rand() * $COLS)}]
        
        if {$board($r,$c) ne "B" && !($r == $safe_r && $c == $safe_c)} {
            set board($r,$c) "B"
            incr placed
        }
    }

    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            if {$board($r,$c) eq "B"} continue
            set count 0
            foreach {dr dc} {-1 -1 -1 0 -1 1 0 -1 0 1 1 -1 1 0 1 1} {
                set nr [expr {$r + $dr}]
                set nc [expr {$c + $dc}]
                if {$nr >= 0 && $nr < $ROWS && $nc >= 0 && $nc < $COLS} {
                    if {$board($nr,$nc) eq "B"} { incr count }
                }
            }
            set board($r,$c) $count
        }
    }
}

proc start_timer {} {
    global time_elapsed timer_id game_over
    if {!$game_over} {
        incr time_elapsed
        set timer_id [after 1000 start_timer]
    }
}

proc click_cell {r c} {
    global game_started game_over state board btn NUM_COLORS revealed_count ROWS COLS BOMBS

    if {$game_over || $state($r,$c) eq "flagged"} return

    if {!$game_started} {
        set game_started 1
        place_bombs $r $c
        start_timer
    }

    if {$state($r,$c) eq "revealed"} return

    set state($r,$c) "revealed"
    incr revealed_count

    if {$board($r,$c) eq "B"} {
        $btn($r,$c) configure -text "💣" -bg red -relief sunken
        game_loss
        return
    }

    if {$board($r,$c) > 0} {
        set val $board($r,$c)
        $btn($r,$c) configure -text $val -fg $NUM_COLORS($val) -relief sunken -state disabled
    } else {
        $btn($r,$c) configure -text "" -relief sunken -state disabled -bg "#e0e0e0"
        
        foreach {dr dc} {-1 -1 -1 0 -1 1 0 -1 0 1 1 -1 1 0 1 1} {
            set nr [expr {$r + $dr}]
            set nc [expr {$c + $dc}]
            if {$nr >= 0 && $nr < $ROWS && $nc >= 0 && $nc < $COLS} {
                if {$state($nr,$nc) eq "hidden"} {
                    click_cell $nr $nc
                }
            }
        }
    }

    if {$revealed_count == ($ROWS * $COLS - $BOMBS)} {
        game_win
    }
}

proc chord_cell {r c} {
    global game_over state board ROWS COLS

    if {$game_over || $state($r,$c) ne "revealed" || $board($r,$c) <= 0} return

    # Count adjacent flags
    set flag_count 0
    set neighbors {}
    
    foreach {dr dc} {-1 -1 -1 0 -1 1 0 -1 0 1 1 -1 1 0 1 1} {
        set nr [expr {$r + $dr}]
        set nc [expr {$c + $dc}]
        if {$nr >= 0 && $nr < $ROWS && $nc >= 0 && $nc < $COLS} {
            if {$state($nr,$nc) eq "flagged"} {
                incr flag_count
            } elseif {$state($nr,$nc) eq "hidden"} {
                lappend neighbors [list $nr $nc]
            }
        }
    }

    # If flags match tile value, reveal remaining unflagged neighbors
    if {$flag_count == $board($r,$c)} {
        foreach pos $neighbors {
            lassign $pos nr nc
            click_cell $nr $nc
        }
    }
}

proc toggle_flag {r c} {
    global game_over state btn flags_left
    if {$game_over || $state($r,$c) eq "revealed"} return

    if {$state($r,$c) eq "hidden"} {
        set state($r,$c) "flagged"
        $btn($r,$c) configure -text "🚩" -fg red
        incr flags_left -1
    } elseif {$state($r,$c) eq "flagged"} {
        set state($r,$c) "hidden"
        $btn($r,$c) configure -text "" -fg black
        incr flags_left 1
    }
}

proc game_loss {} {
    global game_over timer_id board btn state ROWS COLS
    set game_over 1
    after cancel $timer_id
    .top.reset configure -text "😵"

    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            if {$board($r,$c) eq "B" && $state($r,$c) ne "flagged"} {
                $btn($r,$c) configure -text "💣" -relief sunken
            }
        }
    }
}

proc game_win {} {
    global game_over timer_id flags_left
    set game_over 1
    after cancel $timer_id
    set flags_left 0
    .top.reset configure -text "😎"
}

reset_game
