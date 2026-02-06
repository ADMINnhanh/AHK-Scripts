; Main.ahk
#Requires AutoHotkey v2.0

#Include TriangleSelector.ahk

F1:: {
    points := GetThreeClickPoints()
    if (points.Length = 3) {
        MsgBox("你选择了三个点：`n"
            . "(" points[1][1] "," points[1][2] ")`n"
            . "(" points[2][1] "," points[2][2] ")`n"
            . "(" points[3][1] "," points[3][2] ")")
        ; 这里可以处理 points 数组，比如保存、计算面积等
    } else {
        MsgBox("未完成三点选择")
    }
    return
}

; 示例：F2 也做同样事情
F2:: {
    points := GetThreeClickPoints()
    ; 可以做不同逻辑，比如只取前两点
    return
}

Esc:: ExitApp

; 程序退出时清理 GDI+
OnExit(*) => _ts_Cleanup()