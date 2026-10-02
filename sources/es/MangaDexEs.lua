local JSON = require("json")
local socket_url = require("socket.url")

local Source = {}

local API_BASE = "https://api.mangadex.org"
local COVER_BASE = "https://uploads.mangadex.org/covers"
local PAGE_SIZE = 20

local HEADERS = {
    ["Accept"] = "application/json",
    ["User-Agent"] = "TachiKindle/1.0 (KOReader manga plugin) MangaDexES/1.0",
}

local function httpGet(source, path, params)
    local qs = {}
    for _, kv in ipairs(params or {}) do
        table.insert(qs, socket_url.escape(kv[1]) .. "=" .. socket_url.escape(kv[2]))
    end
    local url = API_BASE .. path
    if #qs > 0 then
        url = url .. "?" .. table.concat(qs, "&")
    end
    local body, err = source:fetch(url, { headers = HEADERS })
    if not body then return nil, "HTTP request failed: " .. tostring(err) end

    local ok, decoded = pcall(JSON.decode, body)
    if not ok or type(decoded) ~= "table" then
        return nil, "invalid JSON response from MangaDex"
    end
    if decoded.result ~= "ok" then
        return nil, "MangaDex API error"
    end
    return decoded
end

local function pickTitle(attrs)
    if not attrs then return "Unknown" end
    if attrs.title then
        if attrs.title.es then return attrs.title.es end
        if attrs.title["es-la"] then return attrs.title["es-la"] end
        if attrs.title.en then return attrs.title.en end
    end
    for _, alt in ipairs(attrs.altTitles or {}) do
        if alt.es then return alt.es end
        if alt["es-la"] then return alt["es-la"] end
        if alt.en then return alt.en end
    end
    if attrs.title then
        for _, v in pairs(attrs.title) do return v end
    end
    return "Unknown"
end

local function coverUrlFromRelationships(manga_id, relationships)
    for _, rel in ipairs(relationships or {}) do
        if rel.type == "cover_art" and rel.attributes and rel.attributes.fileName then
            return COVER_BASE .. "/" .. manga_id .. "/" .. rel.attributes.fileName
        end
    end
    return nil
end

local function mangaIdFromUrl(manga_url)
    return tostring(manga_url or ""):match("/title/([%w%-]+)")
end

local function chapterIdFromUrl(chapter_url)
    return tostring(chapter_url or ""):match("/chapter/([%w%-]+)")
end

function Source.fetch_manga_list(source, endpoint_name, page, query)
    page = page or 1
    local offset = (page - 1) * PAGE_SIZE
    local params = {
        { "limit", tostring(PAGE_SIZE) },
        { "offset", tostring(offset) },
        { "includes[]", "cover_art" },
        { "availableTranslatedLanguage[]", "es" },
        { "availableTranslatedLanguage[]", "es-la" },
    }
    if endpoint_name == "popular" then
        table.insert(params, { "order[followedCount]", "desc" })
    elseif endpoint_name == "latest" then
        table.insert(params, { "order[latestUploadedChapter]", "desc" })
    elseif query and query ~= "" then
        table.insert(params, { "title", query })
    else
        table.insert(params, { "order[followedCount]", "desc" })
    end

    local decoded, err = httpGet(source, "/manga", params)
    if not decoded or type(decoded.data) ~= "table" then return nil, err end

    local list = {}
    for _, manga in ipairs(decoded.data) do
        table.insert(list, {
            title = pickTitle(manga.attributes),
            url = source.def.base_url .. "/title/" .. manga.id,
            cover = coverUrlFromRelationships(manga.id, manga.relationships),
        })
    end

    local total = tonumber(decoded.total) or 0
    local has_next = (offset + #list) < total
    return list, nil, has_next
end

function Source.fetch_manga_details(source, manga_url)
    local manga_id = mangaIdFromUrl(manga_url)
    if not manga_id then return nil, "could not parse manga id" end

    local decoded, err = httpGet(source, "/manga/" .. manga_id, {
        { "includes[]", "cover_art" },
        { "includes[]", "author" },
    })
    if not decoded or type(decoded.data) ~= "table" then return nil, err end

    local manga = decoded.data
    local attrs = manga.attributes

    return {
        title = pickTitle(attrs),
        cover = coverUrlFromRelationships(manga.id, manga.relationships),
    }
end

function Source.fetch_chapter_list(source, manga_url)
    local manga_id = mangaIdFromUrl(manga_url)
    if not manga_id then return nil, "could not parse manga id" end

    local chapters = {}
    local limit = 100
    local offset = 0
    local total = math.huge

    for _ = 1, 10 do
        if offset >= total then break end
        local decoded, err = httpGet(source, "/manga/" .. manga_id .. "/feed", {
            { "translatedLanguage[]", "es" },
            { "translatedLanguage[]", "es-la" },
            { "order[chapter]", "desc" },
            { "limit", tostring(limit) },
            { "offset", tostring(offset) },
        })
        if not decoded or type(decoded.data) ~= "table" then return nil, err end

        for _, ch in ipairs(decoded.data) do
            local attrs = ch.attributes or {}
            if not attrs.externalUrl and not attrs.isUnavailable then
                local number = attrs.chapter and ("Capítulo " .. attrs.chapter) or "Capítulo ?"
                local title = attrs.title and attrs.title ~= "" and (number .. ": " .. attrs.title) or number
                table.insert(chapters, {
                    title = title,
                    url = source.def.base_url .. "/chapter/" .. ch.id,
                    date = attrs.publishAt or attrs.readableAt,
                })
            end
        end

        total = tonumber(decoded.total) or #decoded.data
        offset = offset + limit
        if #decoded.data == 0 then break end
    end

    return chapters
end

function Source.fetch_page_list(source, chapter_url)
    local chapter_id = chapterIdFromUrl(chapter_url)
    if not chapter_id then return nil, "could not parse chapter id" end

    local decoded, err = httpGet(source, "/at-home/server/" .. chapter_id, {})
    if not decoded or type(decoded.chapter) ~= "table" then return nil, err end

    local pages = {}
    for _, filename in ipairs(decoded.chapter.data or {}) do
        table.insert(pages, decoded.baseUrl .. "/data/" .. decoded.chapter.hash .. "/" .. filename)
    end
    return pages
end

return Source
