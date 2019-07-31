#raw kRPC constructs
function SendRawProto(outp::IO, obj::Any)
    iob = PipeBuffer()
    writeproto(iob, obj)
    bytes = readavailable(iob)
    varib = PipeBuffer()
    ProtoBuf.write_varint(varib, length(bytes))
    write(outp, readavailable(varib), bytes)
    flush(outp)
end

const MSB = 0x80
const MASK7 = 0x7f
function RecvRawProto(inp::IO)
    flush(inp)
    iob = PipeBuffer()
    res = zero(Int64)
    n = 0
    byte = UInt8(MSB)
    while (byte & MSB) != 0
        flush(inp)
        byte = @sync read(inp, UInt8)
        res |= (convert(Int64, byte & MASK7) << (7*n))
        n += 1
    end
    write(iob, read(inp, res))
    return iob
end

function SendBiMessage(conn::kRPCConnection, req::kRPC.krpc.schema.Request)
    iob = PipeBuffer()
    SendRawProto(conn.conn, req)
    res = readproto(RecvRawProto(conn.conn), krpc.schema.Response())

    if has_field(res, :error)
        throw(make_error(res.error))
    end
    return res
end

function GetInfo(conn::kRPCConnection)
    rv = SendBiMessage(conn, 
        krpc.schema.Request(calls=[krpc.schema.ProcedureCall(service="KRPC", procedure="GetStatus")]))
    if ProtoBuf.has_field(rv, :error)
        throw(make_error(rv.error))
    end
    if ProtoBuf.has_field(rv.results[1], :error)
        throw(make_error(rv.results[1].error))
    end
    iob = PipeBuffer()
    write(iob, rv.results[1].value)
    return readproto(iob, krpc.schema.Status())
end

function GetServices(conn::kRPCConnection)
    rv = SendBiMessage(conn, 
        krpc.schema.Request(calls=[krpc.schema.ProcedureCall(service="KRPC", procedure="GetServices")]))
    if ProtoBuf.has_field(rv, :error)
        throw(make_error(rv.error))
    end
    if ProtoBuf.has_field(rv.results[1], :error)
        throw(make_error(rv.results[1].error))
    end
    iob = PipeBuffer()
    write(iob, rv.results[1].value)
    return readproto(iob, krpc.schema.Services())
end
