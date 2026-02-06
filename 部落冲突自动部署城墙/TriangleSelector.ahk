; TriangleSelector.ahk
#Requires AutoHotkey v2.0

#Include ../Gdip_All.ahk

CoordMode('Mouse', 'Screen')

; 全局状态变量
global _ts_points := []
global _ts_hwnd := 0
global _ts_hdc := 0
global _ts_hbm := 0
global _ts_G := 0
global _ts_pToken := 0
global _ts_obm := 0
global _ts_collecting := false
global _ts_Width := 0
global _ts_Height := 0

_ts_Init() {
    global _ts_pToken, _ts_hwnd, _ts_hbm, _ts_hdc, _ts_obm, _ts_G, _ts_Width, _ts_Height

    if (_ts_pToken)
        return true

    _ts_pToken := Gdip_Startup()
    if (!_ts_pToken) {
        OutputDebug "Gdiplus 启动失败"
        return false
    }

    ; 创建分层窗口（关键：+E0x80000 = WS_EX_LAYERED）
    gui1 := Gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
    gui1.Show("NA")
    _ts_hwnd := WinExist()

    _ts_Width := A_ScreenWidth, _ts_Height := A_ScreenHeight

    ; 创建兼容位图（用于 GDI+ 绘图）
    _ts_hbm := CreateDIBSection(_ts_Width, _ts_Height)
    _ts_hdc := CreateCompatibleDC()
    _ts_obm := SelectObject(_ts_hdc, _ts_hbm)
    _ts_G := Gdip_GraphicsFromHDC(_ts_hdc)
    Gdip_SetSmoothingMode(_ts_G, 4)

    return true
}

_ts_Cleanup() {
    global _ts_pToken, _ts_hdc, _ts_hbm, _ts_G, _ts_obm
    if (!_ts_pToken)
        return
    SelectObject(_ts_hdc, _ts_obm)
    DeleteObject(_ts_hbm)
    DeleteDC(_ts_hdc)
    Gdip_DeleteGraphics(_ts_G)
    Gdip_Shutdown(_ts_pToken)
    _ts_pToken := 0
}

; 清空并绘制当前点（用于预览或最终结果）
_ts_Draw(points, isFinal := false) {
    global _ts_G, _ts_hdc, _ts_hwnd, _ts_Width, _ts_Height

    ; === 关键：每次绘制前先清空为全透明 ===
    Gdip_GraphicsClear(_ts_G, 0x00000000)  ; ARGB: 00=透明, FF=不透明

    if (points.Length < 2)
        return

    pPen := Gdip_CreatePen(isFinal ? 0xFFFF0000 : 0x80FF0000, 2)  ; 最终版不透明，预览半透明

    if (points.Length >= 2) {
        Gdip_DrawLine(_ts_G, pPen, points[1][1], points[1][2], points[2][1], points[2][2])
    }
    if (points.Length >= 3) {
        Gdip_DrawLine(_ts_G, pPen, points[2][1], points[2][2], points[3][1], points[3][2])
        Gdip_DrawLine(_ts_G, pPen, points[3][1], points[3][2], points[1][1], points[1][2])
    }

    Gdip_DeletePen(pPen)

    ; 更新分层窗口（关键：使用 hdc + size）
    UpdateLayeredWindow(_ts_hwnd, _ts_hdc, 0, 0, _ts_Width, _ts_Height)
}

GetThreeClickPoints() {
    global _ts_points, _ts_collecting, _ts_hwnd, _ts_hdc, _ts_G

    if (!_ts_Init())
        return []

    ; === 每次调用时立即清空并显示窗口 ===
    _ts_points := []
    _ts_collecting := true

    ; 显示窗口（分层窗口默认透明，无需 SetTransparent）
    ; WinShow(_ts_hwnd)

    ; 立即清空画布（确保无残留）
    Gdip_GraphicsClear(_ts_G, 0x00000000)
    UpdateLayeredWindow(_ts_hwnd, _ts_hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)

    while (_ts_points.Length < 3) {
        if (!_ts_collecting)
            break

        KeyWait("LButton", "D")
        KeyWait("LButton", "U")

        x := 0, y := 0
        MouseGetPos(&x, &y)
        _ts_points.Push([x, y])
        OutputDebug("记录点: " x ", " y)

        _ts_Draw(_ts_points, false)  ; 预览（半透明）

        Sleep(100)
    }

    ; 绘制最终三角形（不透明）
    if (_ts_points.Length = 3) {
        _ts_Draw(_ts_points, true)
        Sleep(300)  ; 短暂显示
    }

    ; WinHide(_ts_hwnd)

    result := _ts_points.Clone()
    _ts_points := []
    _ts_collecting := false
    return result
}
