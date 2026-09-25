#!/usr/bin/env tclsh

package require Tk

set ROWS 9
set COLS 9
set BOMBS 10

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

wm title . "Tk Minesweeper"
wm resizable . 0 0

frame .top -bd 2 -relief ridge
pack .top -fill x -padx 5 -pady 5

button .top.reset -text "New Game" -font {Helvetica 10 bold} -command reset_game
pack .top.reset -side top -padx 5 -pady 2

frame .board -bd 2 -relief ridge
pack .board -padx 5 -pady 5

proc reset_game {} {
    global ROWS COLS BOMBS game_over game_started revealed_count board state btn

    set game_over 0
    set game_started 0
    set revealed_count 0

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
                   -bg "#d9d9d9" \
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

proc is_safe_zone {r c safe_r safe_c} {
    return [expr {abs($r - $safe_r) <= 1 && abs($c - $safe_c) <= 1}]
}

proc place_bombs {safe_r safe_c} {
    global ROWS COLS BOMBS board

    set safe_zone_size 0
    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            if {[is_safe_zone $r $c $safe_r $safe_c]} { incr safe_zone_size }
        }
    }
    set max_allowed [expr {$ROWS * $COLS - $safe_zone_size}]
    set actual_bombs [expr {$BOMBS > $max_allowed ? $max_allowed : $BOMBS}]

    set placed 0
    while {$placed < $actual_bombs} {
        set r [expr {int(rand() * $ROWS)}]
        set c [expr {int(rand() * $COLS)}]
        
        if {$board($r,$c) ne "B" && ![is_safe_zone $r $c $safe_r $safe_c]} {
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

proc click_cell {r c} {
    global game_started game_over state board btn NUM_COLORS revealed_count ROWS COLS BOMBS

    if {$game_over || $state($r,$c) eq "flagged" || $state($r,$c) eq "revealed"} return

    if {!$game_started} {
        set game_started 1
        place_bombs $r $c
    }

    set state($r,$c) "revealed"
    incr revealed_count

    if {$board($r,$c) eq "B"} {
        $btn($r,$c) configure -text "X" -fg red -bg "#ffcccc" -relief sunken
        game_loss
        return
    }

    if {$board($r,$c) > 0} {
        set val $board($r,$c)
        $btn($r,$c) configure -text $val -fg $NUM_COLORS($val) -relief sunken -bg "#e0e0e0"
    } else {
        $btn($r,$c) configure -text "" -relief sunken -bg "#e0e0e0"
        
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

    update_overlap_highlights

    if {$revealed_count == ($ROWS * $COLS - $BOMBS)} {
        game_win
    }
}

proc chord_cell {r c} {
    global game_over state board ROWS COLS

    if {$game_over || $state($r,$c) ne "revealed" || $board($r,$c) <= 0} return

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

    if {$flag_count == $board($r,$c)} {
        foreach pos $neighbors {
            lassign $pos nr nc
            click_cell $nr $nc
        }
    }
}

proc toggle_flag {r c} {
    global game_over state btn
    if {$game_over || $state($r,$c) eq "revealed"} return

    if {$state($r,$c) eq "hidden"} {
        set state($r,$c) "flagged"
        $btn($r,$c) configure -text "F" -fg red
    } elseif {$state($r,$c) eq "flagged"} {
        set state($r,$c) "hidden"
        $btn($r,$c) configure -text "" -fg black
    }

    update_overlap_highlights
}

# Scans revealed number cells and highlights any cell in light red if adjacent flags exceed its value
proc update_overlap_highlights {} {
    global ROWS COLS board state btn game_over

    if {$game_over} return

    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            if {$state($r,$c) ne "revealed" || $board($r,$c) <= 0} continue

            set flag_count 0
            foreach {dr dc} {-1 -1 -1 0 -1 1 0 -1 0 1 1 -1 1 0 1 1} {
                set nr [expr {$r + $dr}]
                set nc [expr {$c + $dc}]
                if {$nr >= 0 && $nr < $ROWS && $nc >= 0 && $nc < $COLS} {
                    if {$state($nr,$nc) eq "flagged"} {
                        incr flag_count
                    }
                }
            }

            # If adjacent flags strictly exceed the square's number, paint light red
            if {$flag_count > $board($r,$c)} {
                $btn($r,$c) configure -bg "#ff9999"
            } else {
                $btn($r,$c) configure -bg "#e0e0e0"
            }
        }
    }
}

proc game_loss {} {
    global game_over board btn state ROWS COLS
    set game_over 1

    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            if {$board($r,$c) eq "B" && $state($r,$c) ne "flagged"} {
                $btn($r,$c) configure -text "X" -fg red -relief sunken
            }
        }
    }
}

proc game_win {} {
    global game_over board btn state ROWS COLS
    set game_over 1

    for {set r 0} {$r < $ROWS} {incr r} {
        for {set c 0} {$c < $COLS} {incr c} {
            if {$board($r,$c) eq "B" && $state($r,$c) ne "flagged"} {
                set state($r,$c) "flagged"
                $btn($r,$c) configure -text "F" -fg red
            }
        }
    }
}

reset_game
