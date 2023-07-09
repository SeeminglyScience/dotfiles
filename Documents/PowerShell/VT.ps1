$IND = "`eD" # Index
$NEL = "`eE" # Next line
$HTS = "`eH" # Horizontal tab set
$RI  = "`eM" # Reverse index
$SS2 = "`eN" # Single shift 2
$SS3 = "`eO" # Single shift 3
$DCS = "`eP" # Device control string
$SOS = "`eX" # Start of string
$CSI = "`e[" # Control sequence introducer
$ST  = "`e\" # String terminator
$OSC = "`e]" # Operating system command
$PM  = "`e^" # Privacy message
$APC = "`e_" # Application program
$DECID = "`eZ" # VT identification

$ALL_VT = @{
    IND = $IND
    NEL = $NEL
    HTS = $HTS
    RI  = $RI
    SS2 = $SS2
    SS3 = $SS3
    DCS = $DCS
    SOS = $SOS
    CSI = $CSI
    ST  = $ST
    OSC = $OSC
    PM  = $PM
    APC = $APC
    DECID = $DECID
}

function Show-VT {
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Sequence
    )
    process {
        foreach ($vt in $ALL_VT.GetEnumerator()) {
            $Sequence = $Sequence -replace [regex]::Escape($vt.Value), { " $($vt.Key) " }
        }

        $Sequence -replace '\p{Cc}', {
            $value = [int][char]$_.Value
            return [char]($value -lt 0x20 ? $value -bor 0x2400 : $value)
        }
    }
}

function Get-VTInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
    end {
        $uri = 'https://vt100.net/docs/vt510-rm/{0}.html' -f $Name
        $html = (Invoke-WebRequest $uri -UseBasicParsing).ToString()
        $desc = $html | htmlq 'h2 + p' --text
        $seq = $html | htmlq .ctrlseq | htmlq 'span, var' --pretty | Out-String
        $seq = $seq.Trim()
        $seq = $seq `
            -replace '<span class="lit">', ' ' `
            -replace '</span>', ' ' `
            -replace '<var>n</var>', '' `
            -replace '<var>', " $($PSStyle.Italic)" `
            -replace '</var>', "$($PSStyle.ItalicOff)" `
            -replace ' {1,}',' '

        [pscustomobject]@{
            PSTypeName = 'Utility.VTInfo'
            Name = $Name
            Description = $desc
            Sequence = $seq
        }
    }
}

$C0_NUL = "`u{0000}" # Null
$C0_SOH = "`u{0001}" # Start of Heading
$C0_STX = "`u{0002}" # Start of Text
$C0_ETX = "`u{0003}" # End of Text
$C0_EOT = "`u{0004}" # End of Transmission
$C0_ENG = "`u{0005}" # Enquiry
$C0_ACK = "`u{0006}" # Acknowledge
$C0_BEL = "`u{0007}" # Bell
$C0_BS = "`u{0008}"  # Backspace
$C0_HT = "`u{0009}"  # Horizontal Tab
$C0_LF = "`u{000A}"  # Line Feed
$C0_VT = "`u{000B}"  # Vertical Tab
$C0_FF = "`u{000C}"  # Form Feed
$C0_CR = "`u{000D}"  # Carriage Return
$C0_SO = "`u{000E}"  # Shift Out
$C0_SI = "`u{000F}"  # Shift In
$C0_DLE = "`u{0010}" # Data Link Escape
$C0_DC1 = "`u{0011}" # Device Control 1 (XON)
$C0_DC2 = "`u{0012}" # Device Control 2
$C0_DC3 = "`u{0013}" # Device Control 3 (XOFF)
$C0_DC4 = "`u{0014}" # Device Control 4
$C0_NAK = "`u{0015}" # Negative Acknowledge
$C0_SYN = "`u{0016}" # Synchronous Idle
$C0_ETB = "`u{0017}" # End of Transmission Block
$C0_CAN = "`u{0018}" # Cancel
$C0_EM = "`u{0019}"  # End of Medium
$C0_SUB = "`u{001A}" # Substitute
$C0_ESC = "`u{001B}" # Escape
$C0_FS = "`u{001C}"  # File Separator
$C0_GS = "`u{001D}"  # Group Separator
$C0_RS = "`u{001E}"  # Record Separator
$C0_US = "`u{001F}"  # Unit Separator
$C0_DEL = "`u{007F}" # Delete
$C1_SPA = "`u{0096}" # Start of guarded area
$C1_EPA = "`u{0097}" # End of guarded area
