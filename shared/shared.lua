
local fallbackLocale = "en"

function _U(key, ...)
    local selected = Locales and Locales[Config.Locale] or nil
    local fallback = Locales and Locales[fallbackLocale] or nil
    local value = (selected and selected[key]) or (fallback and fallback[key]) or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

function FortunaGetLocale()
    return Config.Locale
end

exports("GetLocale", FortunaGetLocale)
