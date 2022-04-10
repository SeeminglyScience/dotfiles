class TextWalker {
    [int] $Cursor;
    [string] $Text;

    hidden [char[]] $Chars;

    TextWalker([string] $text, [int] $cursor) {
        $this.Chars = $text.ToCharArray()
        $this.Text = $text
        $this.Cursor = $cursor
    }

}

class Extent {
    [Position] $Start;
    [Position] $End;

    Extent([Position] $start, [Position] $end) {
        $this.Start = $start
        $this.End = $end
    }
}

class Position {

}
