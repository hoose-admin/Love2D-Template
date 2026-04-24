"""
Minimal YAML parser for this repo's constrained schemas (SKILL.md frontmatter, fixture files).

Supports:
  - key: scalar
  - nested mappings by 2-space indentation
  - block sequences:  - item
  - block sequences of mappings (- key: val, indented sibling keys)
  - flow sequences: [a, b, c]
  - quoted strings "..." and '...'
  - # comments, blank lines
  - booleans true/false, null/~, integers

Does NOT support: anchors, tags, multi-line folded/literal strings, merge keys.
If you need those, install PyYAML instead.
"""

import re


def _parse_scalar(s):
    s = s.strip()
    if not s:
        return None
    if (s[0] == '"' and s[-1] == '"') or (s[0] == "'" and s[-1] == "'"):
        return s[1:-1]
    if s in ('null', '~'):
        return None
    if s == 'true':
        return True
    if s == 'false':
        return False
    if re.fullmatch(r'-?\d+', s):
        return int(s)
    if s.startswith('[') and s.endswith(']'):
        inner = s[1:-1].strip()
        if not inner:
            return []
        parts = _split_flow(inner)
        return [_parse_scalar(p) for p in parts]
    return s


def _split_flow(s):
    # Split "a, b, \"c, d\"" respecting quotes.
    out, cur, q = [], [], None
    for ch in s:
        if q:
            cur.append(ch)
            if ch == q:
                q = None
        elif ch in ('"', "'"):
            cur.append(ch)
            q = ch
        elif ch == ',':
            out.append(''.join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if cur:
        out.append(''.join(cur).strip())
    return out


def _indent(line):
    return len(line) - len(line.lstrip(' '))


def _strip_comment(line):
    # Strip #-comments that are not inside quotes.
    out, q = [], None
    for ch in line:
        if q:
            out.append(ch)
            if ch == q:
                q = None
        elif ch in ('"', "'"):
            out.append(ch)
            q = ch
        elif ch == '#':
            break
        else:
            out.append(ch)
    return ''.join(out).rstrip()


def _prep_lines(text):
    raw = text.splitlines()
    out = []
    for i, line in enumerate(raw):
        stripped = _strip_comment(line)
        if stripped.strip() == '':
            continue
        out.append((i + 1, _indent(stripped), stripped.rstrip()))
    return out


def parse(text):
    lines = _prep_lines(text)
    result, consumed = _parse_block(lines, 0, 0)
    return result


def _parse_block(lines, idx, base_indent):
    # Decide whether this block is a mapping or a sequence by peeking.
    if idx >= len(lines):
        return None, idx
    _, ind, content = lines[idx]
    if ind < base_indent:
        return None, idx
    if content.lstrip().startswith('- '):
        return _parse_sequence(lines, idx, ind)
    return _parse_mapping(lines, idx, ind)


def _parse_mapping(lines, idx, base_indent):
    out = {}
    while idx < len(lines):
        lineno, ind, content = lines[idx]
        if ind < base_indent:
            break
        if ind > base_indent:
            raise ValueError(f"line {lineno}: unexpected indent {ind} > {base_indent}")
        content = content.lstrip()
        if content.startswith('- '):
            break
        if ':' not in content:
            raise ValueError(f"line {lineno}: expected 'key: value', got {content!r}")
        k, _, v = content.partition(':')
        k = k.strip()
        v = v.strip()
        if v == '':
            idx += 1
            if idx < len(lines) and lines[idx][1] > base_indent:
                child, idx = _parse_block(lines, idx, lines[idx][1])
                out[k] = child
            else:
                out[k] = None
        else:
            out[k] = _parse_scalar(v)
            idx += 1
    return out, idx


def _parse_sequence(lines, idx, base_indent):
    out = []
    while idx < len(lines):
        lineno, ind, content = lines[idx]
        if ind < base_indent:
            break
        if ind > base_indent:
            raise ValueError(f"line {lineno}: unexpected indent in sequence")
        c = content.lstrip()
        if not c.startswith('- '):
            break
        rest = c[2:].strip()
        if ':' in rest and not (rest.startswith('"') or rest.startswith("'")):
            # Inline first key of a mapping item.
            first_k, _, first_v = rest.partition(':')
            first_k = first_k.strip()
            first_v = first_v.strip()
            item = {}
            if first_v:
                item[first_k] = _parse_scalar(first_v)
            else:
                item[first_k] = None
            idx += 1
            # Continuation lines belong to this item if indented > base_indent.
            cont_indent = base_indent + 2
            if idx < len(lines) and lines[idx][1] >= cont_indent:
                child, idx = _parse_mapping(lines, idx, lines[idx][1])
                item.update(child)
            # If first_v was empty and next line is deeper, attach as child value.
            if first_v == '' and item[first_k] is None:
                # Already handled by the mapping-merge above if the structure is flat.
                pass
            out.append(item)
        else:
            # Scalar list item.
            out.append(_parse_scalar(rest))
            idx += 1
    return out, idx


if __name__ == '__main__':
    import sys, json
    text = sys.stdin.read() if len(sys.argv) == 1 else open(sys.argv[1]).read()
    print(json.dumps(parse(text), indent=2, default=str))
