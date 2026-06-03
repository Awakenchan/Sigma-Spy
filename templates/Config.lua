return {
    VariableNames = {"RIFT_IS_DETECTED%.d", "Skibidi%.d", "AURA%.d", "Sigma%.d", "Mango%.d", "Phonk%.d", "Argument%.d"},
    SyntaxColors = {
        Text = Color3.fromRGB(204, 204, 204),
        Background = Color3.fromRGB(20,20,20),
        Selection = Color3.fromRGB(255,255,255),
        SelectionBack = Color3.fromRGB(102, 161, 255),
        Operator = Color3.fromRGB(204, 204, 204),
        Number = Color3.fromRGB(255, 198, 0),
        String = Color3.fromRGB(172, 240, 148),
        Comment = Color3.fromRGB(102, 102, 102),
        Keyword = Color3.fromRGB(248, 109, 124),
        BuiltIn = Color3.fromRGB(132, 214, 247),
        LocalMethod = Color3.fromRGB(253, 251, 172),
        LocalProperty = Color3.fromRGB(97, 161, 241),
        Nil = Color3.fromRGB(255, 198, 0),
        Bool = Color3.fromRGB(255, 198, 0),
        Function = Color3.fromRGB(248, 109, 124),
        Local = Color3.fromRGB(248, 109, 124),
        Self = Color3.fromRGB(248, 109, 124),
        FunctionName = Color3.fromRGB(253, 251, 172),
        Bracket = Color3.fromRGB(204, 204, 204)
    },
    MethodColors = {
        ["fireserver"] = Color3.fromRGB(242, 255, 0),
        ["invokeserver"] = Color3.fromRGB(99, 86, 245),
        ["onclientevent"] = Color3.fromRGB(77, 245, 105),
        ["onclientinvoke"] = Color3.fromRGB(77, 178, 245),
        ["event"] = Color3.fromRGB(77, 245, 181),
        ["invoke"] = Color3.fromRGB(245, 77, 77),
        ["oninvoke"] = Color3.fromRGB(245, 77, 209),
        ["fire"] = Color3.fromRGB(245, 141, 77),
    },
    BlackListedServices = {
        "RobloxReplicatedStorage"
    },
    NoReceiveHooking = true,
    ThemeConfig = {
        BaseTheme = "ImGui",
        TextSize = 12
    }
}
