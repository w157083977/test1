#!./cell

local sc = import 'schedule'
local so = import 'socket'
local json   = import 'cjson'
local object = import 'object'
local vrs = require('vrs')

-- S2 interface server
S2InterfaceServer = object.Object:extend()
function S2InterfaceServer:init(host, port)
    self.stream = so.TcpServer:new(host, port)
    log (format("[%s] listen at [%s:%d]", self:getClassName(), host, port))
    self:initVar()
end

function S2InterfaceServer:initVar()
    self._connect = {}
    self._user_list = {}
    self._seq = 1

end

function S2InterfaceServer:start()
    sc.routine(self.mainRoutine, self)
end

function S2InterfaceServer:mainRoutine()
    while true do
        local peer = self.stream:accept(128)
        sc.routine(self.processRoutine, self, peer)
    end
end

function S2InterfaceServer:encode(head, body)
    buff = ''
    head.total_len = 28 + #body
    buff = string.pack(">!1i4i4c16HHc"..tostring(#body), 
    head.total_len, head.seq, head.bind_id, 
    head.msg_type, head.head_ext_len, body)
    return buff
end

function S2InterfaceServer:parse(buff)
    local head = {}
    local ext_head = {}
    local body = ''

    if #buff < 4 then
        return 0
    end

    total_len = string.unpack(">!1i4", buff)
    print("total_len = ", total_len)
    local pos = 1
    pos = pos + 4

    if #buff >= total_len then
        --table.insert( head, {"total_len", total_len} )
        head.total_len = total_len
        seq = string.unpack(">!1i4", buff, pos)
        pos = pos + 4
        --table.insert( head, {"seq", seq} )
        head.seq = seq
        bind_id = string.unpack(">!1c16", buff, pos)
        pos = pos + 16
        --table.insert(head, {"bind_id", bind_id})
        head.bind_id = bind_id        
        msg_type = string.unpack(">!1H", buff, pos)
        pos = pos + 2
        --table.insert(head, {"msg_type", msg_type})
        head.msg_type = msg_type
        head_ext_len = string.unpack(">!1H", buff, pos)
        pos = pos + 2
        --table.insert(head, {"head_ext_len", head_ext_len})
        head.head_ext_len = head_ext_len
	if head.head_ext_len > 0 then
        	js = string.unpack(">!1c"..tostring(head_ext_len), buff, pos)
        	pos = pos + head_ext_len
        	ext_head = json.decode(js)
	end
        body_len = total_len - pos + 1
        body = string.unpack(">!1c"..tostring(body_len), buff, pos)
        return total_len, head, ext_head, body        
    else
        return 0
    end
end

function S2InterfaceServer:processRoutine(peer)
    local buff = nil
    while true do
        local ok, data = sc.pcall(peer.read, peer)
        if  not ok or not data then
            peer:close()
            return
        end
        if not buff then
            buff = data
        else 
            buff = buff .. data
        end

        --one loop for 1000 msg, it is enough
        for i=1, 1000 do            
            local len, head, exthead, body = self:parse(buff)
            if len > 0 then
                --process message
                print(dump(head))
                print(string.tohex(head.bind_id))
                print(dump(exthead))
                print(string.tohex(body))
                buff = buff:sub(len + 1)
            
                local bind_id = head.bind_id
                self._connect[bind_id] = peer
            
                if head.msg_type == 2 then
                    local user_info = {}
                    user_info.bind_id = head.bind_id
                    user_info.user_id = exthead.user_id
                    user_info.user_name = exthead.user_name
                    local user_id = user_info.user_id
                    self._user_list[user_id] = user_info
                    print(dump(self._user_list))                
                elseif  head.msg_type == 1 then
                    head.head_ext_len = 0                
                    body_temp = body
                    while #body_temp > 0 do	
                        local ret, msg_type, msg, err = vrs.decode_rtcm3(body_temp)
                        print("ret = ", ret, " msg_type=", msg_type, "err=", err)
                        if msg ~= nil then                 	    
			    print(string.tohex(msg))
		        end
                        if ret == 0 then
                            if #body_temp ~= 0 then print("warning, body_left=", string.tohex(body_temp)) end
			    break
                        end
                        body_temp = body_temp:sub(ret + 1)			
                    end	
                    for k, v in pairs(self._user_list) do
                        bind_id = v.bind_id
                        p = self._connect[bind_id]
                        head.seq = self._seq
                        self._seq = self._seq + 1
                        rsp = self:encode(head, body)
                        p:write(rsp)
                    end
                end               

                --head.head_ext_len = 0
                --head.seq = self._seq
                --self._seq = self._seq + 1
                --rsp = self:encode(head, body)
                --peer:write(rsp)
            else
                break
            end
        end
    end
end



function main()
    sc.sighandle('sigint', function () 
        os.exit(102)  
    end)

    local s1_interface = S2InterfaceServer:new("0.0.0.0", 8101)
    s1_interface:start()
end
