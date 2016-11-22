require 'class'

clue.class("RealizedLazySeq")
clue.class("UnrealizedLazySeq")

function clue.UnrealizedLazySeq:init(fn)
    self.fn = fn
end

function clue.UnrealizedLazySeq:realize()
    local fn = self.fn
    self.seq = fn and fn() or clue.list()
    self.fn = nil
    setmetatable(self, clue.RealizedLazySeq)
end

function clue.UnrealizedLazySeq:first()
    self:realize()
    return self.seq:first()
end

function clue.UnrealizedLazySeq:next()
    self:realize()
    return self.seq:next()
end

function clue.UnrealizedLazySeq:empty()
    self:realize()
    return self.seq:empty()
end

function clue.UnrealizedLazySeq:with_meta(m)
    local wm = clue.UnrealizedLazySeq.new(self.fn)
    wm.meta = m
    return wm
end

function clue.RealizedLazySeq:first()
    return self.seq:first()
end

function clue.RealizedLazySeq:next()
    return self.seq:next()
end

function clue.RealizedLazySeq:empty()
    return self.seq:empty()
end

function clue.RealizedLazySeq:with_meta(m)
    local wm = clue.RealizedLazySeq.new()
    wm.seq = self.seq
    wm.meta = m
    return wm
end

clue.lazy_seq = clue.UnrealizedLazySeq.new
