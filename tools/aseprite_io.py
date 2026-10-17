# Minimal Aseprite (.aseprite) reader/writer for RGBA (32bpp) files, so
# tools can read layers/cels and add new layers without the Aseprite CLI.
# Every chunk is kept raw, so anything we don't parse (tags, palettes,
# slices, user data) round-trips untouched.
# Usage: import from another tool script, e.g.
#   from aseprite_io import Ase
#   a = Ase(path); img = a.composite(0); a.save(path)
import struct, zlib
import numpy as np

LAYER, CEL, CEL_EXTRA, OLD_PAL1, OLD_PAL2, PAL, TAGS, CPROF, USER, SLICE = (
    0x2004, 0x2005, 0x2006, 0x0004, 0x0011, 0x2019, 0x2018, 0x2007, 0x2020, 0x2022)


class Chunk:
    def __init__(self, ctype, data):
        self.type = ctype
        self.data = data  # bytes (without 6-byte header)


class Frame:
    def __init__(self, duration, chunks):
        self.duration = duration
        self.chunks = chunks


class Ase:
    def __init__(self, path):
        b = open(path, 'rb').read()
        self.header = bytearray(b[:128])
        (fsize, magic, nframes, self.w, self.h, self.depth, self.flags) = struct.unpack_from('<IHHHHHI', b, 0)
        assert magic == 0xA5E0, hex(magic)
        assert self.depth == 32, f'depth {self.depth} unsupported'
        off = 128
        self.frames = []
        for _ in range(nframes):
            flen, fmagic, old_n, dur = struct.unpack_from('<IHHH', b, off)
            assert fmagic == 0xF1FA
            new_n = struct.unpack_from('<I', b, off + 12)[0]
            n = new_n if new_n else old_n
            p = off + 16
            chunks = []
            for _ in range(n):
                clen, ctype = struct.unpack_from('<IH', b, p)
                chunks.append(Chunk(ctype, bytes(b[p + 6:p + clen])))
                p += clen
            self.frames.append(Frame(dur, chunks))
            off += flen

    # ---- layers -------------------------------------------------------
    def layers(self):
        out = []
        for c in self.frames[0].chunks:
            if c.type == LAYER:
                flags, ltype, child, _, _, blend, opacity = struct.unpack_from('<HHHHHHB', c.data, 0)
                nlen = struct.unpack_from('<H', c.data, 16)[0]
                name = c.data[18:18 + nlen].decode('utf8')
                out.append(dict(flags=flags, type=ltype, child=child, blend=blend,
                                opacity=opacity, name=name))
        return out

    # ---- cels ---------------------------------------------------------
    def cel_image(self, fi, li, _depth=0):
        """Return (x, y, HxWx4 uint8 array) or None for layer li in frame fi."""
        for c in self.frames[fi].chunks:
            if c.type != CEL:
                continue
            lidx, x, y, op, ctype, z = struct.unpack_from('<HhhBHh', c.data, 0)
            if lidx != li:
                continue
            body = c.data[16:]
            if ctype == 1:
                return self.cel_image(struct.unpack_from('<H', body, 0)[0], li)
            w, h = struct.unpack_from('<HH', body, 0)
            raw = body[4:] if ctype == 0 else zlib.decompress(body[4:])
            return x, y, np.frombuffer(raw, np.uint8).reshape(h, w, 4).copy()
        return None

    def layer_canvas(self, fi, li):
        img = np.zeros((self.h, self.w, 4), np.uint8)
        r = self.cel_image(fi, li)
        if r:
            x, y, a = r
            h, w = a.shape[:2]
            # clip
            x0, y0 = max(x, 0), max(y, 0)
            x1, y1 = min(x + w, self.w), min(y + h, self.h)
            if x1 > x0 and y1 > y0:
                img[y0:y1, x0:x1] = a[y0 - y:y1 - y, x0 - x:x1 - x]
        return img

    def composite(self, fi, include=None):
        """Normal-blend composite of visible image layers (alpha-over).
        include: optional set of layer indices to limit the composite to."""
        out = np.zeros((self.h, self.w, 4), np.float32)
        for li, L in enumerate(self.layers()):
            if L['type'] != 0 or not (L['flags'] & 1):
                continue
            if include is not None and li not in include:
                continue
            src = self.layer_canvas(fi, li).astype(np.float32) / 255
            sa = src[..., 3:4] * (L['opacity'] / 255)
            da = out[..., 3:4]
            oa = sa + da * (1 - sa)
            rgb = np.where(oa > 0, (src[..., :3] * sa + out[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6), 0)
            out = np.concatenate([rgb, oa], -1)
        return (out * 255 + 0.5).astype(np.uint8)

    # ---- editing ------------------------------------------------------
    def add_layer(self, name, opacity=255):
        """Append a normal image layer at top level. Returns its index."""
        n = len(self.layers())
        nb = name.encode('utf8')
        data = struct.pack('<HHHHHHB3s', 3, 0, 0, 0, 0, 0, opacity, b'\0\0\0')
        data += struct.pack('<H', len(nb)) + nb
        # insert after last layer chunk in frame 0
        ch = self.frames[0].chunks
        last = max(i for i, c in enumerate(ch) if c.type == LAYER)
        # skip user-data chunk attached to that layer, if any
        ins = last + 1
        while ins < len(ch) and ch[ins].type == USER:
            ins += 1
        ch.insert(ins, Chunk(LAYER, data))
        return n

    def set_cel(self, fi, li, img):
        """img: full-canvas HxWx4 uint8. Stored cropped to its bbox."""
        self.frames[fi].chunks = [c for c in self.frames[fi].chunks
                                  if not (c.type == CEL and struct.unpack_from('<H', c.data, 0)[0] == li)]
        ys, xs = np.nonzero(img[..., 3])
        if len(xs) == 0:
            return
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        crop = np.ascontiguousarray(img[y0:y1, x0:x1])
        data = struct.pack('<HhhBHh5s', li, int(x0), int(y0), 255, 2, 0, b'\0' * 5)
        data += struct.pack('<HH', x1 - x0, y1 - y0) + zlib.compress(crop.tobytes())
        self.frames[fi].chunks.append(Chunk(CEL, data))

    def save(self, path):
        body = b''
        for f in self.frames:
            cb = b''.join(struct.pack('<IH', len(c.data) + 6, c.type) + c.data for c in f.chunks)
            n = len(f.chunks)
            fh = struct.pack('<IHHH2sI', 16 + len(cb), 0xF1FA, min(n, 0xFFFF), f.duration, b'\0\0', n)
            body += fh + cb
        hdr = bytearray(self.header)
        struct.pack_into('<I', hdr, 0, 128 + len(body))
        struct.pack_into('<H', hdr, 6, len(self.frames))
        open(path, 'wb').write(bytes(hdr) + body)


def tags(a):
    for c in a.frames[0].chunks:
        if c.type == TAGS:
            n = struct.unpack_from('<H', c.data, 0)[0]
            p = 10
            out = []
            for _ in range(n):
                f, t = struct.unpack_from('<HH', c.data, p)
                nl = struct.unpack_from('<H', c.data, p + 17)[0]
                out.append((f, t, c.data[p + 19:p + 19 + nl].decode()))
                p += 19 + nl
            return out
    return []
