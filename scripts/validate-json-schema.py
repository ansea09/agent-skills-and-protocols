#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any


class SchemaError(Exception):
    pass


def type_name(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int) and not isinstance(value, bool):
        return "integer"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def matches_type(value: Any, expected: str) -> bool:
    return type_name(value) == expected or (expected == "number" and type_name(value) == "integer")


def validate(schema: dict[str, Any], value: Any, path: str = "$") -> None:
    expected_type = schema.get("type")
    if isinstance(expected_type, list):
        if not any(matches_type(value, item) for item in expected_type):
            raise SchemaError(f"{path}: expected one of {expected_type}, got {type_name(value)}")
    elif isinstance(expected_type, str) and not matches_type(value, expected_type):
        raise SchemaError(f"{path}: expected {expected_type}, got {type_name(value)}")

    if "enum" in schema and value not in schema["enum"]:
        raise SchemaError(f"{path}: expected one of {schema['enum']!r}, got {value!r}")
    if "const" in schema and value != schema["const"]:
        raise SchemaError(f"{path}: expected {schema['const']!r}, got {value!r}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise SchemaError(f"{path}: missing required property {key!r}")

        properties = schema.get("properties", {})
        for key, child in properties.items():
            if key in value:
                validate(child, value[key], f"{path}.{key}")

        additional = schema.get("additionalProperties", True)
        extra_keys = set(value) - set(properties)
        if additional is False and extra_keys:
            names = ", ".join(sorted(extra_keys))
            raise SchemaError(f"{path}: unexpected properties: {names}")
        if isinstance(additional, dict):
            for key in sorted(extra_keys):
                validate(additional, value[key], f"{path}.{key}")

    if isinstance(value, list) and "items" in schema:
        for index, item in enumerate(value):
            validate(schema["items"], item, f"{path}[{index}]")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate-json-schema.py SCHEMA_JSON DOCUMENT_JSON", file=sys.stderr)
        return 2
    schema_path = Path(argv[0])
    document_path = Path(argv[1])
    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        document = json.loads(document_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON: {exc}", file=sys.stderr)
        return 1
    try:
        validate(schema, document)
    except SchemaError as exc:
        print(f"ERROR: JSON schema validation failed for {document_path}: {exc}", file=sys.stderr)
        return 1
    print(f"OK: JSON schema valid: {document_path.name} against {schema_path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
