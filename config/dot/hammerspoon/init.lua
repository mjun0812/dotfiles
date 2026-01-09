-- URLで呼べる「中央寄せ」
hs.urlevent.bind("center", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:centerOnScreen(nil, true) -- trueで画面外(ドック下など)に行きにくくする
  end)