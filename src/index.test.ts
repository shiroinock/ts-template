import { describe, expect, it } from "vitest";
import { greet } from "./index.js";

describe("greet", () => {
  it("returns greeting message with name", () => {
    expect(greet("World")).toBe("Hello, World!");
  });
});
