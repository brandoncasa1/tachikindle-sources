local Source = {}

local function limpiar_texto(texto)
    if not texto then return "Sin título" end
    return texto:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
end

function Source.fetch_manga_list(source, endpoint_name, page, query)
    local url = source.def.base_url
    if query and query ~= "" then
        url = url .. "/?s=" .. query:gsub(" ", "+")
    elseif page and page > 1 then
        url = url .. "/page/" .. tostring(page) .. "/"
    end
    
    local body, err = source:fetch(url)
    if not body then return nil, err end
    
    local list = {}
    local procesados = {}
    
    for href, title in body:gmatch('<a[^>]+href="([^"]+)"[^>]*title="([^"]+)"') do
        if (href:find("/manga/") or href:find("/comic/")) and not procesados[href] then
            table.insert(list, { title = limpiar_texto(title), url = href })
            procesados[href] = true
        end
    end
    return list, nil, true
end

function Source.fetch_manga_details(source, manga_url)
    return { title = "Detalles de la obra" }
end

function Source.fetch_chapter_list(source, manga_url)
    local body, err = source:fetch(manga_url)
    if not body then return nil, err end
    
    local chapters = {}
    local procesados = {}
    
    for href, contenido in body:gmatch('<a[^>]+href="([^"]+)"[^>]*>(.-)</a>') do
        if (href:find("capitulo") or href:find("chapter") or href:find("%-cap%-")) and not href:find("facebook") then
            if not procesados[href] then
                table.insert(chapters, { title = limpiar_texto(contenido), url = href })
                procesados[href] = true
            end
        end
    end
    return chapters
end

function Source.fetch_page_list(source, chapter_url)
    local body, err = source:fetch(chapter_url)
    if not body then return nil, err end
    
    local pages = {}
    for src in body:gmatch('<img[^>]+src="([^"]+)"') do
        if src:find("%.jpg") or src:find("%.png") or src:find("%.webp") or src:find("uploads") then
            if not src:find("logo") and not src:find("icon") and not src:find("avatar") then
                table.insert(pages, src)
            end
        end
    end
    return pages
end

return Source