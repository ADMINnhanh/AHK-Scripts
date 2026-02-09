; ==============================================
; 图片查看器类
; ==============================================
class ImageViewer {
    hwnd := 0          ; 窗口句柄
    gui := ""          ; GUI 对象
    bitmap := 0        ; GDI+ 位图
    hdc := 0           ; 设备上下文
    hbm := 0           ; 位图句柄
    g := 0             ; GDI+ 图形对象

    ; 配置属性
    imagePath := ""    ; 图片路径
    targetW := 500     ; 目标宽度
    targetH := 500     ; 目标高度
    scaleMode := 2     ; 缩放模式 (1:保持比例, 2:填充拉伸, 3:居中裁剪)
    alpha := 1.0       ; 透明度 (0.0-1.0)
    isLocked := false  ; 鼠标穿透锁定

    ; ==============================================
    ; 显示图片
    ; ==============================================
    ShowImage(imagePath, targetW := 500, targetH := 500) {
        ; 保存参数
        this.imagePath := imagePath
        this.targetW := targetW
        this.targetH := targetH

        ; 创建窗口
        this.CreateWindow()

        ; 先显示窗口以获取有效句柄
        this.gui.Show("w" this.targetW " h" this.targetH " NA")
        this.hwnd := this.gui.Hwnd
        this.EnsureResizableStyle()
        this.CenterOnScreen()
        ; 加载并绘制图片
        this.LoadAndDraw()

        return this.gui
    }

    ; ==============================================
    ; 创建显示窗口
    ; ==============================================
    CreateWindow() {
        ; 创建无边框透明窗口
        this.gui := Gui("+AlwaysOnTop +ToolWindow -Caption +Resize +E0x80000 +LastFound", "图片查看器")
        this.gui.BackColor := "000000"
        ; 句柄在 Show 之后才有效，延后赋值

        ; 设置窗口事件
        this.gui.OnEvent("Close", this.Close.Bind(this))
        this.gui.OnEvent("Size", this.OnSize.Bind(this))
        OnMessage(0x84, this.OnNcHitTest.Bind(this))
        ; 在 Show 后由 ShowImage 赋值 hwnd 并设置透明色
    }

    ; ==============================================
    ; 加载并绘制图片
    ; ==============================================
    LoadAndDraw() {
        ; 清理之前的资源
        this.CleanupGraphics()

        ; 获取窗口尺寸
        WinGetPos(, , &w, &h, "ahk_id " this.hwnd)
        if (w = 0 || h = 0) {
            w := this.targetW
            h := this.targetH
        }

        ; 创建内存设备上下文
        screenDC := DllCall("GetDC", "ptr", 0, "ptr")
        this.hbm := CreateDIBSection(w, h, screenDC)
        this.hdc := CreateCompatibleDC(screenDC)
        DllCall("ReleaseDC", "ptr", 0, "ptr", screenDC)

        ; 选择位图到DC
        this.obm := SelectObject(this.hdc, this.hbm)

        ; 创建 GDI+ 图形对象
        this.g := Gdip_GraphicsFromHDC(this.hdc)
        if (!this.g) {
            MsgBox("创建 GDI+ 图形对象失败")
            return
        }

        ; 设置高质量渲染
        Gdip_SetInterpolationMode(this.g, 7)  ; 高质量插值
        Gdip_SetSmoothingMode(this.g, 4)      ; 抗锯齿
        Gdip_SetCompositingMode(this.g, 1)    ; 源复制模式

        ; 加载图片
        this.bitmap := Gdip_CreateBitmapFromFile(this.imagePath)
        if (!this.bitmap) {
            MsgBox("无法加载图片: " this.imagePath)
            return
        }

        ; 绘制图片
        this.DrawImageToDC()

        ; 更新分层窗口（不改变当前位置）
        UpdateLayeredWindow(this.hwnd, this.hdc, , , w, h, Round(this.alpha * 255))
    }

    ; ==============================================
    ; 绘制图片到设备上下文
    ; ==============================================
    DrawImageToDC() {
        ; 获取图片和窗口尺寸
        imgW := Gdip_GetImageWidth(this.bitmap)
        imgH := Gdip_GetImageHeight(this.bitmap)
        WinGetPos(, , &winW, &winH, "ahk_id " this.hwnd)

        if (imgW = 0 || imgH = 0 || winW = 0 || winH = 0) {
            return
        }

        ; 计算绘制参数
        params := this.CalcDrawParams(imgW, imgH, winW, winH)

        ; 清除背景（透明）
        Gdip_GraphicsClear(this.g, 0x00000000)

        ; 绘制图片（不使用矩阵透明，透明度仅由窗口 Alpha 控制）
        Gdip_DrawImage(this.g, this.bitmap,
            params.x, params.y, params.w, params.h,
            0, 0, imgW, imgH)
    }
    EnsureResizableStyle() {
        if (!this.hwnd) {
            return
        }
        GWL_STYLE := -16
        WS_THICKFRAME := 0x00040000
        style := 0
        if (A_PtrSize = 8) {
            style := DllCall("GetWindowLongPtr", "ptr", this.hwnd, "int", GWL_STYLE, "ptr")
            DllCall("SetWindowLongPtr", "ptr", this.hwnd, "int", GWL_STYLE, "ptr", style | WS_THICKFRAME)
        } else {
            style := DllCall("GetWindowLong", "ptr", this.hwnd, "int", GWL_STYLE, "int")
            DllCall("SetWindowLong", "ptr", this.hwnd, "int", GWL_STYLE, "int", style | WS_THICKFRAME)
        }
    }

    ; ==============================================
    ; 计算绘制参数
    ; ==============================================
    CalcDrawParams(imgW, imgH, winW, winH) {

        switch this.scaleMode {
            case 1:  ; 保持比例
                ratioW := winW / imgW
                ratioH := winH / imgH
                scale := Min(ratioW, ratioH)
                newW := imgW * scale
                newH := imgH * scale
                x := (winW - newW) / 2
                y := (winH - newH) / 2

            case 2:  ; 填充拉伸
                newW := winW
                newH := winH
                x := 0
                y := 0

            case 3:  ; 居中裁剪
                ratioW := winW / imgW
                ratioH := winH / imgH
                scale := Max(ratioW, ratioH)
                newW := imgW * scale
                newH := imgH * scale
                x := (winW - newW) / 2
                y := (winH - newH) / 2

            default:
                ; 默认保持比例
                ratioW := winW / imgW
                ratioH := winH / imgH
                scale := Min(ratioW, ratioH)
                newW := imgW * scale
                newH := imgH * scale
                x := (winW - newW) / 2
                y := (winH - newH) / 2
        }

        return { x: x, y: y, w: newW, h: newH }
    }

    ; ==============================================
    ; 设置缩放模式
    ; ==============================================
    SetScaleMode(mode) {
        if (mode < 1 || mode > 3) {
            return
        }

        this.scaleMode := mode
        if (this.hwnd && WinExist("ahk_id " this.hwnd)) {
            this.LoadAndDraw()
        }
    }

    ; ==============================================
    ; 设置透明度
    ; ==============================================
    SetAlpha(alpha) {
        ; 限制透明度范围
        if (alpha < 0) {
            alpha := 0
        } else if (alpha > 1) {
            alpha := 1
        }

        this.alpha := alpha
        if (this.hwnd && WinExist("ahk_id " this.hwnd)) {
            WinGetPos(, , &w, &h, "ahk_id " this.hwnd)
            UpdateLayeredWindow(this.hwnd, this.hdc, , , w, h, Round(alpha * 255))
        }
    }

    ; ==============================================
    ; 设置新图片
    ; ==============================================
    SetImage(imagePath) {
        if (!FileExist(imagePath)) {
            MsgBox("图片文件不存在: " imagePath)
            return
        }

        this.imagePath := imagePath

        ; 清理旧图片
        if (this.bitmap) {
            Gdip_DisposeImage(this.bitmap)
            this.bitmap := 0
        }

        ; 重新加载图片
        this.LoadAndDraw()
    }

    ; ==============================================
    ; 窗口大小变化事件
    ; ==============================================
    OnSize(guiObj, minMax, width, height) {
        ; 延迟重绘，避免频繁刷新
        this.targetW := width
        this.targetH := height
        SetTimer(() => this.LoadAndDraw(), -16)
    }
    OnNcHitTest(msg, wParam, lParam, hwnd) {
        if (hwnd != this.hwnd)
            return 0
        if (this.isLocked)
            return 0
        pt := Buffer(8)
        DllCall("GetCursorPos", "ptr", pt)
        x := NumGet(pt, 0, "int")
        y := NumGet(pt, 4, "int")
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this.hwnd)
        border := 8
        left := x < wx + border
        right := x >= wx + ww - border
        top := y < wy + border
        bottom := y >= wy + wh - border
        if (top && left) {
            return 13
        } else if (top && right) {
            return 14
        } else if (bottom && left) {
            return 16
        } else if (bottom && right) {
            return 17
        } else if (left) {
            return 10
        } else if (right) {
            return 11
        } else if (top) {
            return 12
        } else if (bottom) {
            return 15
        } else {
            return 2
        }
    }
    SetLocked(locked) {
        this.isLocked := !!locked
        if (!this.hwnd) {
            return
        }
        GWL_EXSTYLE := -20
        WS_EX_TRANSPARENT := 0x00000020
        ex := 0
        if (A_PtrSize = 8) {
            ex := DllCall("GetWindowLongPtr", "ptr", this.hwnd, "int", GWL_EXSTYLE, "ptr")
            newEx := this.isLocked ? (ex | WS_EX_TRANSPARENT) : (ex & ~WS_EX_TRANSPARENT)
            DllCall("SetWindowLongPtr", "ptr", this.hwnd, "int", GWL_EXSTYLE, "ptr", newEx)
        } else {
            ex := DllCall("GetWindowLong", "ptr", this.hwnd, "int", GWL_EXSTYLE, "int")
            newEx := this.isLocked ? (ex | WS_EX_TRANSPARENT) : (ex & ~WS_EX_TRANSPARENT)
            DllCall("SetWindowLong", "ptr", this.hwnd, "int", GWL_EXSTYLE, "int", newEx)
        }
    }
    CenterOnScreen() {
        if (!this.hwnd) {
            return
        }
        hmon := DllCall("MonitorFromWindow", "ptr", this.hwnd, "uint", 2, "ptr")
        mi := Buffer(40, 0)
        NumPut("uint", 40, mi, 0)
        if (!DllCall("GetMonitorInfo", "ptr", hmon, "ptr", mi)) {
            return
        }
        wl := NumGet(mi, 20, "int")
        wt := NumGet(mi, 24, "int")
        wr := NumGet(mi, 28, "int")
        wb := NumGet(mi, 32, "int")
        ww := wr - wl
        wh := wb - wt
        WinGetPos(, , &w, &h, "ahk_id " this.hwnd)
        x := wl + (ww - w) / 2
        y := wt + (wh - h) / 2
        WinMove(x, y, w, h, "ahk_id " this.hwnd)
    }

    ; ==============================================
    ; 显示窗口
    ; ==============================================
    Show() {
        if (this.gui) {
            this.gui.Show("NA")
            this.LoadAndDraw()
        }
    }

    ; ==============================================
    ; 隐藏窗口
    ; ==============================================
    Hide() {
        if (this.gui) {
            this.gui.Hide()
        }
    }

    ; ==============================================
    ; 清理图形资源
    ; ==============================================
    CleanupGraphics() {
        ; GDI+ 图形
        if (this.g) {
            Gdip_DeleteGraphics(this.g)
            this.g := 0
        }

        ; 位图
        if (this.bitmap) {
            Gdip_DisposeImage(this.bitmap)
            this.bitmap := 0
        }

        ; GDI 资源
        if (this.hbm) {
            SelectObject(this.hdc, this.obm)
            DeleteObject(this.hbm)
            this.hbm := 0
            this.obm := 0
        }

        if (this.hdc) {
            DeleteDC(this.hdc)
            this.hdc := 0
        }
    }

    ; ==============================================
    ; 完全清理
    ; ==============================================
    Cleanup() {
        ; 清理图形资源
        this.CleanupGraphics()

        ; 销毁窗口
        if (this.gui) {
            try {
                this.gui.Destroy()
            } catch as e {
                ; 忽略可能的错误
            }
            this.gui := ""
            this.hwnd := 0
        }
    }

    ; ==============================================
    ; 关闭事件
    ; ==============================================
    Close(guiObj) {
        this.Cleanup()
    }
}
