#!/usr/bin/env python3
"""PNG 과 .icns 를 무손실로 다시 압축한다.

CoreGraphics(ImageIO) 가 내보내는 PNG 는 압축을 얕게 건다. 픽셀은 그대로 두고
필터를 다시 고르고 zlib 을 최대로 조이기만 해도 아이콘이 절반 가까이 줄어든다.
표시되는 그림은 한 픽셀도 달라지지 않는다 — 검사는 --verify 로 한다.

    ./scripts/shrink-png.py Resources/AppIcon.icns          # 제자리 압축
    ./scripts/shrink-png.py --verify 원본.icns 압축본.icns   # 픽셀 동일 검사
"""
import struct
import sys
import zlib

# 아이콘에는 쓸모없는 메타데이터 청크. 색 공간(sRGB/iCCP/gAMA)은 남긴다.
DROPPED_CHUNKS = {b"eXIf", b"tEXt", b"zTXt", b"iTXt", b"tIME", b"pHYs"}
BYTES_PER_PIXEL = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def iter_chunks(data):
    offset = 8
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        yield kind, data[offset + 8:offset + 8 + length]
        offset += 12 + length


def make_chunk(kind, payload):
    crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def unfilter(raw, width, height, bpp):
    """필터를 풀어 순수 스캔라인으로 되돌린다."""
    stride = width * bpp
    rows = bytearray()
    prior = bytearray(stride)
    pos = 0
    for _ in range(height):
        kind = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if kind == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif kind == 2:
            for i in range(stride):
                line[i] = (line[i] + prior[i]) & 0xFF
        elif kind == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prior[i]) >> 1)) & 0xFF
        elif kind == 4:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                upleft = prior[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + paeth(left, prior[i], upleft)) & 0xFF
        rows += line
        prior = line
    return bytes(rows)


def refilter(rows, width, height, bpp):
    """줄마다 다섯 필터를 다 재보고 절대값 합이 가장 작은 것을 고른다 (libpng 휴리스틱)."""
    stride = width * bpp
    out = bytearray()
    prior = bytearray(stride)
    for y in range(height):
        line = rows[y * stride:(y + 1) * stride]
        best = None
        best_score = None
        best_kind = 0
        for kind in range(5):
            cand = bytearray(stride)
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                up = prior[i]
                upleft = prior[i - bpp] if i >= bpp else 0
                x = line[i]
                if kind == 0:
                    v = x
                elif kind == 1:
                    v = x - left
                elif kind == 2:
                    v = x - up
                elif kind == 3:
                    v = x - ((left + up) >> 1)
                else:
                    v = x - paeth(left, up, upleft)
                cand[i] = v & 0xFF
            score = sum(v if v < 128 else 256 - v for v in cand)
            if best_score is None or score < best_score:
                best, best_score, best_kind = cand, score, kind
        out.append(best_kind)
        out += best
        prior = line
    return bytes(out)


def shrink_png(data):
    """더 작아졌으면 새 PNG 를, 아니면 None 을 돌려준다."""
    header = None
    idat = b""
    kept = []
    for kind, payload in iter_chunks(data):
        if kind == b"IHDR":
            header = payload
            kept.append((kind, payload))
        elif kind == b"IDAT":
            idat += payload
        elif kind == b"IEND" or kind in DROPPED_CHUNKS:
            continue
        else:
            kept.append((kind, payload))
    if header is None:
        return None
    width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", header[:13])
    if depth != 8 or interlace != 0 or color not in BYTES_PER_PIXEL:
        return None  # 다루지 않는 형식은 건드리지 않는다
    bpp = BYTES_PER_PIXEL[color]
    rows = unfilter(zlib.decompress(idat), width, height, bpp)
    candidates = (
        zlib.compress(refilter(rows, width, height, bpp), 9),
        zlib.compress(zlib.decompress(idat), 9),
    )
    out = PNG_MAGIC
    for kind, payload in kept:
        out += make_chunk(kind, payload)
    out += make_chunk(b"IDAT", min(candidates, key=len)) + make_chunk(b"IEND", b"")
    return out if len(out) < len(data) else None


def icns_entries(data):
    entries = []
    offset = 8
    while offset < len(data):
        kind = data[offset:offset + 4]
        length = struct.unpack(">I", data[offset + 4:offset + 8])[0]
        if length < 8:
            break
        entries.append((kind, data[offset + 8:offset + length]))
        offset += length
    return entries


def shrink_icns(data):
    body = b""
    for kind, payload in icns_entries(data):
        if payload[:8] == PNG_MAGIC:
            smaller = shrink_png(payload)
            if smaller:
                payload = smaller
        body += kind + struct.pack(">I", len(payload) + 8) + payload
    out = b"icns" + struct.pack(">I", len(body) + 8) + body
    return out if len(out) < len(data) else None


def decode_pixels(png):
    header = None
    idat = b""
    for kind, payload in iter_chunks(png):
        if kind == b"IHDR":
            header = payload
        elif kind == b"IDAT":
            idat += payload
    width, height, depth, color, _, _, _ = struct.unpack(">IIBBBBB", header[:13])
    bpp = BYTES_PER_PIXEL[color]
    return (width, height, color), unfilter(zlib.decompress(idat), width, height, bpp)


def verify(before_path, after_path):
    """압축 전후의 픽셀이 한 바이트도 다르지 않은지 확인한다."""
    before = open(before_path, "rb").read()
    after = open(after_path, "rb").read()
    if before[:8] == PNG_MAGIC:
        pairs = [(b"png ", before, after)]
    else:
        a, b = icns_entries(before), icns_entries(after)
        if [k for k, _ in a] != [k for k, _ in b]:
            print("엔트리 구성이 다르다", file=sys.stderr)
            return False
        pairs = [(k, pa, pb) for (k, pa), (_, pb) in zip(a, b)]
    ok = True
    for kind, pa, pb in pairs:
        if pa[:8] == PNG_MAGIC:
            same = decode_pixels(pa) == decode_pixels(pb)
        else:
            same = pa == pb
        print(f"  {kind.decode('latin1')}: {'동일' if same else '★다름★'}")
        ok &= same
    print("픽셀 완전 동일 ✓" if ok else "불일치 ✗")
    return ok


def main(argv):
    if len(argv) >= 2 and argv[0] == "--verify":
        return 0 if verify(argv[1], argv[2]) else 1
    if not argv:
        print(__doc__)
        return 2
    total_before = total_after = 0
    for path in argv:
        data = open(path, "rb").read()
        smaller = shrink_icns(data) if not data[:8] == PNG_MAGIC else shrink_png(data)
        total_before += len(data)
        if smaller is None:
            total_after += len(data)
            print(f"  {path}: {len(data):,} bytes (개선 없음)")
            continue
        open(path, "wb").write(smaller)
        total_after += len(smaller)
        saved = 100 - 100 * len(smaller) / len(data)
        print(f"  {path}: {len(data):,} → {len(smaller):,} bytes ({saved:.1f}% 절감)")
    if len(argv) > 1:
        saved = 100 - 100 * total_after / total_before
        print(f"  합계: {total_before:,} → {total_after:,} bytes ({saved:.1f}% 절감)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
