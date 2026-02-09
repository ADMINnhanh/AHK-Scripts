#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================
; 包含 GDI+ 库和显示模块
; ==============================================
#Include ../Gdip_All.ahk
#Include Display.ahk

; 主程序入口
global g_pToken := ""    ; GDI+ 令牌
global g_viewer := ""    ; 图片查看器实例
global g_imagePath := "" ; 当前图片路径
global g_isVisible := true ; 窗口可见状态

; 初始化程序
InitProgram()

; 主循环
Persistent()

; ==============================================
; 初始化函数
; ==============================================
InitProgram() {
    global g_viewer, g_isVisible, g_imagePath, g_pToken

    ; 1. 智能加载图片
    g_imagePath := LoadImage()
    if (g_imagePath = "") {
        ExitApp()
    }

    ; 2. 初始化 GDI+
    g_pToken := Gdip_Startup()
    if (!g_pToken) {
        MsgBox("GDI+ 初始化失败，请确保系统已安装 .NET Framework。")
        ExitApp()
    }

    ; 3. 创建图片查看器
    g_viewer := ImageViewer()
    g_viewer.ShowImage(g_imagePath)
}

; ==============================================
; 智能图片加载函数
; ==============================================
LoadImage() {
    ; 优先使用命令行参数
    if (A_Args.Length > 0) {
        path := A_Args[1]
        if (FileExist(path)) {
            return path
        } else {
            MsgBox("命令行指定的图片不存在:`n" path)
            return ""
        }
    }

    ; 尝试加载默认图片
    defaultImages := []
    ; defaultImages := [
    ;     A_ScriptDir "\1.png"
    ; ]

    for path in defaultImages {
        if (FileExist(path)) {
            return path
        }
    }

    ; 弹出文件选择对话框
    try {
        selectedFile := FileSelect(3, A_ScriptDir, "选择图片文件", "图片文件 (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff)")
        if (selectedFile) {
            return selectedFile
        }
    } catch as e {
        MsgBox("文件选择失败: " e.Message)
    }

    MsgBox("未找到可用的图片文件，程序将退出。")
    return ""
}

; ==============================================
; 热键设置
; ==============================================
; F1: 显示/隐藏切换
F1:: ToggleVisibility()

; F2: 切换缩放模式
F2:: ToggleScaleMode()

; F3: 切换透明度
F3:: ToggleTransparency()

; F4: 锁定窗口为鼠标穿透
F4:: ToggleLock()

; F5: 重新加载图片（开发调试用）
F5:: ReloadImage()

; ESC: 退出程序
Esc:: ExitProgram()

; ==============================================
; 热键处理函数
; ==============================================
ToggleVisibility() {
    global g_viewer, g_isVisible

    if (!g_viewer) {
        return
    }

    if (g_isVisible) {
        g_viewer.Hide()
        g_isVisible := false
        ToolTip("窗口已隐藏")
    } else {
        g_viewer.Show()
        g_isVisible := true
        ToolTip("窗口已显示")
    }

    SetTimer(() => ToolTip(), -1000)
}

ToggleScaleMode() {
    global g_viewer

    if (!g_viewer) {
        return
    }

    static currentMode := 1
    currentMode := Mod(currentMode, 3) + 1

    modes := Map(
        1, "保持比例",
        2, "填充拉伸",
        3, "居中裁剪"
    )

    g_viewer.SetScaleMode(currentMode)
    ToolTip("缩放模式: " modes[currentMode])
    SetTimer(() => ToolTip(), -1500)
}

ToggleTransparency() {
    global g_viewer

    if (!g_viewer) {
        return
    }

    static alphaLevels := [0.2, 0.5, 0.8, 1.0]
    static currentIndex := 4

    currentIndex := Mod(currentIndex, alphaLevels.Length) + 1
    newAlpha := alphaLevels[currentIndex]

    g_viewer.SetAlpha(newAlpha)
    ToolTip("透明度: " Round(newAlpha * 100) "%")
    SetTimer(() => ToolTip(), -1500)
}

ReloadImage() {
    global g_viewer, g_imagePath

    if (g_viewer && g_imagePath) {
        g_viewer.SetImage(g_imagePath)
        ToolTip("图片已重新加载")
        SetTimer(() => ToolTip(), -1000)
    }
}

ToggleLock() {
    global g_viewer
    if (!g_viewer) {
        return
    }
    static locked := false
    locked := !locked
    g_viewer.SetLocked(locked)
    ToolTip(locked ? "窗口已锁定，鼠标穿透" : "窗口已解锁，正常交互")
    SetTimer(() => ToolTip(), -1500)
}
ExitProgram() {
    global g_viewer, g_pToken

    ; 清理资源
    if (g_viewer) {
        g_viewer.Cleanup()
    }

    ; 关闭 GDI+
    if (g_pToken) {
        try {
            Gdip_Shutdown(g_pToken)
        } catch as e {
            ; 忽略清理错误
        }
    }

    ExitApp()
}

; ==============================================
; 程序退出处理
; ==============================================
OnExit(ExitFunc)

ExitFunc(ExitReason, ExitCode) {
    ExitProgram()
    return 1
}
