#!/usr/bin/env lem
--
-- This file is part of blipserver.
-- Copyright 2011 Emil Renner Berthing
--
-- blipserver is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- blipserver is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with blipserver.  If not, see <http://www.gnu.org/licenses/>.
--

local function usage()
	print('Labitrack daemon')
	print('usage:    '..arg[0]..' [bind [queue_dir]]')
	print('defaults: bind=*:8080 queue_dir=./queue')
	os.exit(1)
end

--
-- settings
--
local pg_connect_str = 'host=localhost user=labitrack dbname=labitrack password=nerfyoawdAj3'
local bind = arg[1] or '*:8080'
local queue_dir = arg[2] or './queue'
--
-- end of settings
--

local bind_colon = string.find(bind, ':', 1, true)
if bind_colon == nil then
	usage()
end
local bind_addr = string.sub(bind, 1, bind_colon-1)
local bind_port = tonumber(string.sub(bind, bind_colon+1))

local utils        = require 'lem.utils'
local postgres     = require 'lem.postgres'
local qpostgres    = require 'lem.postgres.queued'
local hathaway     = require 'lem.hathaway'
local json         = require 'dkjson'
local base64       = require 'base64'
local filequeue    = require 'filequeue'

local assert = assert
local format = string.format
local tonumber = tonumber

local function sendfile(content, path)
	return function(req, res)
		res.headers['Content-Type'] = content
		res.file = path
	end
end

local function sendfile_js(path)
	return sendfile('text/javascript; charset=UTF-8', path)
end

local function sendfile_css(path)
	return sendfile('text/css; charset=UTF-8', path)
end

local function deserialize_array_from_pg(pgarray)
	local ret, rc = {}, 0
	if pgarray == nil then
		return ret
	end
	local strlen = string.len(pgarray)
	if strlen <= 2 then
		return ret
	end
	local n = 0
	for i = 2, strlen-1 do
		if i > n then
			rc = rc + 1
			n = string.find(pgarray, ',', i)
			if n == nil then
				n = strlen
			end
			ret[rc] = string.sub(pgarray, i, n-1)
		end
	end
	return ret
end

local function add_json_row(res, values, i)
	local n = #values
	if n > 0 then
		local clen = #values[0]
		local point = values[i]
		local d = {}
		for j = 1, clen do
			local k = values[0][j]
			local v = point[j]
			if k == nil then
			elseif k == 'id' then
				d[k] = tonumber(v)
			elseif k == 'created' then
				d[k] = tonumber(v)
			elseif k == 'updated' then
				d[k] = tonumber(v)
			elseif not (k == 'tags') then
				d[k] = v
			else
				d[k] = deserialize_array_from_pg(v)
			end
		end
		res:add('%s', json.encode(d))
	end
end


local function add_json(res, values)
	local n = #values
	res:add('[')
	if n > 0 then
		for i = 1, n do
			add_json_row(res, values, i)
			if not (i == n) then
				res:add(',')
			end
		end
	end
	res:add(']')
end

local function set_json_nocache_headers(res)
	res.headers['Content-Type'] = 'application/json; charset=UTF-8'
	res.headers['Cache-Control'] = 'max-age=0, must-revalidate'
end

local function unescape(s)
	s = string.gsub(s, "+", " ")
	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	end)
	return s
end

-- Connect to database and prepare statements
local db = assert(qpostgres.connect(pg_connect_str))
local cols = 'id, name, "desc", tags, extract(epoch from created)::int8 created, extract(epoch from updated)::int8 updated'
assert(db:prepare('get',    'SELECT '..cols..' FROM objects WHERE id = $1'))
assert(db:prepare('recent', 'SELECT '..cols..' FROM objects ORDER BY updated DESC LIMIT 10;'))
assert(db:prepare('since',  'SELECT '..cols..' FROM objects ORDER BY id LIMIT 10 OFFSET $1;'))
assert(db:prepare('insert', 'INSERT INTO objects (name, "desc", tags) VALUES ($1, $2, string_to_array($3, \',\')::text[]) RETURNING id;'))
assert(db:prepare('update', 'UPDATE objects SET name=$2, "desc"=$3, tags=string_to_array($4, \',\')::text[], updated=now() WHERE id = $1;'))
assert(db:prepare('count',  'SELECT COUNT(id) FROM objects;'))
assert(db:prepare('search', 'SELECT * FROM (SELECT row_number() over (order by rank desc, updated desc) as rn, * FROM (SELECT count(*) over () as cnt, '..cols..', ts_rank_cd(textsearch, query) AS rank FROM objects, to_tsquery($1) query WHERE query @@ textsearch) ss1) ss2 where rn between $2+1 and $2+10;'))
assert(db:prepare('search_plain', 'SELECT plainto_tsquery($1);'))

local function count()
	return assert(db:run('count'))[1][1]
end

-- initialize queue
local queue = filequeue.open(queue_dir)

hathaway.import()

local htmlpage = sendfile('text/html; charset=UTF-8', 'pub/index.html')

GET('/',                   htmlpage)
GET('/browse',             htmlpage)
GETM('^/browse/page/%d+$', htmlpage)
GET('/recent',             htmlpage)
GET('/about',              htmlpage)
GETM('^/view/%d+$',        htmlpage)
GETM('^/edit/%d+$',        htmlpage)
GET('/search',             htmlpage)
GETM('^/search/',          htmlpage)

GET('/js/corelibs.min.js',  sendfile_js('js/dist/corelibs.min.js'))
GET('/js/corelibs.src.js',  sendfile_js('js/dist/corelibs.src.js'))
GET('/js/qrcode.min.js',    sendfile_js('js/dist/qrcode.min.js'))
GET('/js/labitrack.min.js', sendfile_js('js/dist/labitrack.min.js'))
GET('/js/labitrack.src.js', sendfile_js('js/dist/labitrack.src.js'))
GET('/js/templates.js',     sendfile_js('templates/dist/labitrack.min.js'))

GET('/bootstrap/css/bootstrap.css', sendfile_css('pub/bootstrap/css/bootstrap.css'))
GET('/bootstrap/css/bootstrap.min.css', sendfile_css('pub/bootstrap/css/bootstrap.min.css'))
GET('/bootstrap/css/bootstrap-responsive.css', sendfile_css('pub/bootstrap/css/bootstrap-responsive.css'))
GET('/bootstrap/css/bootstrap-responsive.min.css', sendfile_css('pub/bootstrap/css/bootstrap-responsive.min.css'))
GET('/bootstrap/img/glyphicons-halflings-white.png', sendfile_css('pub/bootstrap/img/glyphicons-halflings-white.png'))
GET('/bootstrap/img/glyphicons-halflings.png', sendfile_css('pub/bootstrap/img/glyphicons-halflings.png'))

GET('/css/labitrack.css',           sendfile_css('css/dist/labitrack.min.css'))

GET('/favicon.ico', sendfile('image/x-icon', 'pub/favicon.ico'))

GETM('^/browse/(%d+).json$', function(req, res, since)
	set_json_nocache_headers(res)

	res:add('{"count": %d, "objects":', count());
	add_json(res, assert(db:run('since', (since-1)*10)))
	res:add('}');
end)

local function urldecode(str)
	return str:gsub('+', ' '):gsub('%%(%x%x)', function (str)
		return string.char(tonumber(str, 16))
	end)
end
local function parse_qs(str)
	local t = {}
	for k, v in str:gmatch('([^&]+)=([^&]*)') do
		t[urldecode(k)] = urldecode(v)
	end
	return t
end

GETM('^/search.json%??(.*)$', function(req, res, rawqs)
	set_json_nocache_headers(res)

	qs = parse_qs(rawqs)

	q = qs['q']

	if q == nil then
		q = ''
	end

	offset = qs['offset']
	if offset == nil then
		offset = 0
	end

	_, result = pcall(db.run, db, 'search', q, offset)

	if result == nil then
		q = assert(db:run('search_plain', q))[1][1]
		result = assert(db:run('search', q, offset))
	end

	local n = #result
	if n > 0 then
		cols = #result[0]
		setmetatable(result[0], { __len = function(op)
			return cols
		end })
		result[0][1] = nil
		result[0][2] = nil
		cnt = result[1][2]

		res:add('{"count": %d, "offset": %d, "query": %s, "objects":', cnt, offset, json.encode(q));
		add_json(res, result)
		res:add('}');
	else
		res:add('{"count": 0, "offset": 0, "query": %s}', json.encode(q));
	end
end)

GET('/queue.json', function(req, res)
	set_json_nocache_headers(res)
	res:add('%s', json.encode(queue:stat()))
end)

GET('/queue.json?empty', function(req, res)
	set_json_nocache_headers(res)
	res:add('%s', json.encode(queue:empty()))
end)

GET('/recent.json', function(req, res)
	set_json_nocache_headers(res)
	add_json(res, assert(db:run('recent')))
end)

local function unescape(s)
	s = string.gsub(s, "+", " ")
	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	end)
	return s
end

local function save_or_update(req, res)
	set_json_nocache_headers(res)

	local expected = "application/json"
	assert(string.sub(req.headers['Content-Type'], 1, string.len(expected)) == expected)

	local body = req:body()
	local label = json.decode(body)

	local id
	if label['id'] == nil then
		id = assert(db:run('insert', label['name'], label['desc'], table.concat(label['tags'], ',')))[1][1]
	else
		assert(db:run('update', label['id'], label['name'], label['desc'], table.concat(label['tags'], ',')))
		id = label['id']
	end

	res:add('{"id": %d}', id)
end

POST('/o', save_or_update)
PUTM('^/o/(%d+).json$', save_or_update)

GETM('^/o/(%d+).json$', function(req, res, id)
	set_json_nocache_headers(res)

	qr = db:run('get', id)
	if #qr == 0 then
		res.status = 404
	else
		add_json_row(res, qr, 1)
	end
end)


POST('/print.json', function(req, res)
	set_json_nocache_headers(res)

	local expected = "application/x-www-form-urlencoded"
	assert(string.sub(req.headers['Content-Type'], 1, string.len(expected)) == expected)

	local body = unescape(req:body())
	expected = "image=data:image/png;base64,"
	local expected_len = string.len(expected)
	assert(string.sub(body, 1, expected_len) == expected)
	image = base64.dec(string.sub(body, expected_len+1))

	local qi = queue:new()
	local outfile = qi:open("wb")
	outfile:write(image)
	outfile:close()
	qi:queue();

	res:add('["%s"]', 'OK')
end)

hathaway.debug = print
assert(Hathaway(bind_addr, bind_port))

-- vim: syntax=lua ts=2 sw=2 noet:
