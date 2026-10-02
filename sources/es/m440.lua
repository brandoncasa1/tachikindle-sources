local http = require("socket.http")
local ltn12 = require("ltn12")

local Source = {}

local function request_html(url)
    local response_body = {}
    local res, code = http.request{
        url = url,
        method = "GET",
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        },
        sink = ltn12.sink.table(response_body)
    }
    if code == 200 then
        return table.concat(response_body)
    end
    return nil
end

function Source:fetch_manga_list(page, query)
    local url = "https://m440.in"
    if page and page > 1 then
        url = string.format("https://m440.in/page/%d/", page)
    end
    
    local html = request_html(url)
    if not html then return {} end
    
    local list = {}
    for href, title in html:gmatch('<a%s+href="([^"]+)"%s+title="([^"]+)"') do
        if href:find("/manga/") or href:find("/comic/") or href:find("m440.in") then
            table.insert(list, {
                id = href,
                title = title,
                url = href
            })
        end
    end
    return list
end

function Source:fetch_chapter_list(manga_url)
    local html = request_html(manga_url)
    if not html then return {} end
    
    local chapters = {}
    for href, name in html:gmatch('<a%s+href="([^"]+)"[^>]*class="[^"]*chapter[^"]*"[^>]*>(.-)</a>') do
        local clean_name = name:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
        table.insert(chapters, {
            id = href,
            title = clean_name,
            url = href
        })
    end
    
    if #chapters == 0 then
        for href, name in html:gmatch('<a%s+href="([^"]+)"[^>]*>(.-)</a>') do
            if href:find("capitulo") or href:find("chapter") then
                local clean_name = name:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
                table.insert(chapters, {
                    id = href,
                    title = clean_name,
                    url = href
                })
            end
        end
    end
    return chapters
end

function Source:fetch_page_list(chapter_url)
    local html = request_html(chapter_url)
    if not html then return {} end
    
    local pages = {}
    for src in html:gmatch('<img%s+[^>]*src="([^"]+)"') do
        if src:find("wp-content") or src:find("uploads") or src:find("%.jpg") or src:find("%.png") or src:find("%.webp") then
            table.insert(pages, src)
        end
    end
    return pages
end

return Source
