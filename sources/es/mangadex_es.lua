local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")

local Source = {}

local function request_json(url)
    local response_body = {}
    local res, code = http.request{
        url = url,
        method = "GET",
        headers = {
            ["User-Agent"] = "TachiKindle/1.0 MangaDexES/1.0",
            ["Accept"] = "application/json"
        },
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        return json.decode(table.concat(response_body))
    end
    return nil
end

function Source:fetch_manga_list(page, query)
    page = page or 1
    local offset = (page - 1) * 20
    local url = string.format("https://api.mangadex.org/manga?limit=20&offset=%d&availableTranslatedLanguage[]=es&availableTranslatedLanguage[]=es-la&order[followedCount]=desc", offset)
    
    if query and query ~= "" then
        url = string.format("https://api.mangadex.org/manga?limit=20&offset=%d&title=%s&availableTranslatedLanguage[]=es&availableTranslatedLanguage[]=es-la", offset, query)
    end

    local data = request_json(url)
    if not data or not data.data then return {} end

    local list = {}
    for _, item in ipairs(data.data) do
        local title = "Sin título"
        if item.attributes and item.attributes.title then
            title = item.attributes.title.es or item.attributes.title["es-la"] or item.attributes.title.en or select(2, next(item.attributes.title)) or title
        end

        table.insert(list, {
            id = item.id,
            title = title,
            url = "https://api.mangadex.org/title/" .. item.id
        })
    end
    return list
end

function Source:fetch_chapter_list(manga_url)
    local manga_id = manga_url:match("title/(.+)$") or manga_url
    local url = string.format("https://api.mangadex.org/manga/%s/feed?translatedLanguage[]=es&translatedLanguage[]=es-la&order[chapter]=desc&limit=500", manga_id)
    
    local data = request_json(url)
    if not data or not data.data then return {} end

    local chapters = {}
    for _, ch in ipairs(data.data) do
        local num = ch.attributes.chapter or "?"
        local title = "Capítulo " .. num
        if ch.attributes.title and ch.attributes.title ~= "" then
            title = title .. " - " .. ch.attributes.title
        end
        table.insert(chapters, {
            id = ch.id,
            title = title,
            url = "https://api.mangadex.org/chapter/" .. ch.id
        })
    end
    return chapters
end

function Source:fetch_page_list(chapter_url)
    local chapter_id = chapter_url:match("chapter/(.+)$") or chapter_url
    local url = string.format("https://api.mangadex.org/at-home/server/%s", chapter_id)
    
    local data = request_json(url)
    if not data or not data.chapter then return {} end

    local host = data.baseUrl
    local hash = data.chapter.hash
    local pages = {}

    for _, file in ipairs(data.chapter.data or {}) do
        table.insert(pages, string.format("%s/data/%s/%s", host, hash, file))
    end
    return pages
end

return Source
