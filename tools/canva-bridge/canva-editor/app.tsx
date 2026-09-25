import { Alert, Button, Rows, Text, Title } from "@canva/app-ui-kit";
import { openDesign, type DesignEditing } from "@canva/design";
import { useEffect, useState } from "react";

const OWNER = "JCoorp";
const REPO = "SnackUP-core";
const REF = "feat/canva-bridge-v1";
const RECIPE_PATH = "tools/canva-bridge/recipes/latest.json";

type Target = {
  page?: number;
  type?: "text" | "rect" | "shape" | "embed" | "group";
  text_contains?: string;
  media?: "image" | "video";
  index?: number;
};

type Operation =
  | { type: "replace_text"; page?: number; find: string; replace: string; case_sensitive?: boolean; exact?: boolean }
  | { type: "format_text"; page?: number; find?: string; case_sensitive?: boolean; formatting: Record<string, unknown> }
  | { type: "move"; target: Target; dx?: number; dy?: number; left?: number; top?: number }
  | { type: "resize"; target: Target; scale?: number; width?: number; height?: number; keep_center?: boolean }
  | { type: "set_transparency"; target: Target; transparency: number }
  | { type: "set_background_color"; page?: number; color: string }
  | { type: "set_rect_color"; target: Target; color: string }
  | { type: "set_shape_color"; target: Target; color: string }
  | { type: "delete_elements"; target: Target }
  | { type: "add_text"; page?: number; text: string; left: number; top: number; width: number; formatting?: Record<string, unknown> };

type Recipe = { version: number; name: string; scope?: "all_pages"; operations: Operation[] };

function githubContentsUrl() {
  return `https://api.github.com/repos/${OWNER}/${REPO}/contents/${RECIPE_PATH}?ref=${encodeURIComponent(REF)}&t=${Date.now()}`;
}

async function loadRecipe(): Promise<Recipe> {
  const response = await fetch(githubContentsUrl(), { headers: { Accept: "application/vnd.github+json" } });
  if (!response.ok) throw new Error(`GitHub ${response.status}: no se pudo cargar la receta`);
  const data = await response.json();
  const base64 = String(data.content || "").replace(/\n/g, "");
  const json = decodeURIComponent(escape(atob(base64)));
  return JSON.parse(json) as Recipe;
}

function normalize(s: string, sensitive = false) { return sensitive ? s : s.toLocaleLowerCase(); }

function textMatches(text: string, needle?: string, sensitive = false, exact = false) {
  if (!needle) return true;
  const a = normalize(text, sensitive), b = normalize(needle, sensitive);
  return exact ? a === b : a.includes(b);
}

function elementMatches(element: DesignEditing.AbsoluteElement, target: Target) {
  if (element.type === "unsupported" || element.locked) return false;
  if (target.type && element.type !== target.type) return false;
  if (target.text_contains) {
    if (element.type !== "text" || !textMatches(element.text.readPlaintext(), target.text_contains)) return false;
  }
  if (target.media) {
    if (element.type !== "rect") return false;
    const media = element.fill.mediaContainer?.ref;
    if (media?.type !== target.media) return false;
  }
  return true;
}

function selectedElements(page: DesignEditing.AbsolutePage, target: Target) {
  const matches = page.elements.toArray().filter((el) => elementMatches(el, target));
  if (target.index == null) return matches;
  const item = matches[target.index];
  return item ? [item] : [];
}

async function applyRecipe(recipe: Recipe) {
  return openDesign({ type: "all_pages" }, async (session) => {
    const refs = session.pageRefs.toArray();
    for (let pageIndex = 0; pageIndex < refs.length; pageIndex++) {
      const pageRef = refs[pageIndex];
      if (pageRef.type !== "absolute" || pageRef.locked) continue;
      await session.helpers.openPage(pageRef, async ({ page, helpers }) => {
        for (const op of recipe.operations) {
          const pageNumber = "page" in op && op.page != null ? op.page : ("target" in op ? op.target.page : undefined);
          if (pageNumber != null && pageNumber !== pageIndex + 1) continue;

          if (op.type === "replace_text") {
            page.elements.forEach((element) => {
              if (element.type !== "text" || element.locked) return;
              const current = element.text.readPlaintext();
              const haystack = normalize(current, op.case_sensitive);
              const needle = normalize(op.find, op.case_sensitive);
              if (op.exact ? haystack !== needle : !haystack.includes(needle)) return;
              if (op.exact) {
                element.text.replaceText({ index: 0, length: current.length }, op.replace);
              } else {
                let from = 0;
                while (true) {
                  const latest = element.text.readPlaintext();
                  const idx = normalize(latest, op.case_sensitive).indexOf(needle, from);
                  if (idx < 0) break;
                  element.text.replaceText({ index: idx, length: op.find.length }, op.replace);
                  from = idx + op.replace.length;
                }
              }
            });
          } else if (op.type === "format_text") {
            page.elements.forEach((element) => {
              if (element.type !== "text" || element.locked) return;
              const text = element.text.readPlaintext();
              if (!op.find) {
                element.text.formatText({ index: 0, length: text.length }, op.formatting as never);
                return;
              }
              const idx = normalize(text, op.case_sensitive).indexOf(normalize(op.find, op.case_sensitive));
              if (idx >= 0) element.text.formatText({ index: idx, length: op.find.length }, op.formatting as never);
            });
          } else if (op.type === "set_background_color") {
            if (page.background) page.background.colorContainer.set({ type: "solid", color: op.color.toLowerCase() });
          } else if (op.type === "add_text") {
            const range = helpers.elementStateBuilder.createRichtextRange();
            range.appendText(op.text, op.formatting as never);
            page.elements.insertAfter(undefined, helpers.elementStateBuilder.createTextElement({
              left: op.left, top: op.top, width: op.width, text: { regions: range.readTextRegions() },
            }));
          } else {
            const elements = selectedElements(page, op.target);
            for (const element of elements) {
              if (op.type === "move") {
                if (op.left != null) element.left = op.left; else element.left += op.dx || 0;
                if (op.top != null) element.top = op.top; else element.top += op.dy || 0;
              } else if (op.type === "resize") {
                const oldW = element.width, oldH = element.height;
                const scale = op.scale ?? 1;
                const newW = op.width ?? oldW * scale;
                const newH = op.height ?? oldH * scale;
                if (op.keep_center !== false) {
                  element.left -= (newW - oldW) / 2;
                  element.top -= (newH - oldH) / 2;
                }
                element.width = newW; element.height = newH;
              } else if (op.type === "set_transparency") {
                element.transparency = op.transparency;
              } else if (op.type === "set_rect_color" && element.type === "rect") {
                element.fill.colorContainer.set({ type: "solid", color: op.color.toLowerCase() });
              } else if (op.type === "set_shape_color" && element.type === "shape") {
                element.paths.forEach((p) => p.fill.colorContainer.set({ type: "solid", color: op.color.toLowerCase() }));
              } else if (op.type === "delete_elements") {
                page.elements.delete(element);
              }
            }
          }
        }
      });
    }
    await session.sync();
  });
}

export function App() {
  const [recipe, setRecipe] = useState<Recipe | null>(null);
  const [status, setStatus] = useState<string>("Cargando receta...");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const reload = async () => {
    setError(null); setStatus("Cargando receta...");
    try { const r = await loadRecipe(); setRecipe(r); setStatus("Receta lista"); }
    catch (e) { setError(e instanceof Error ? e.message : String(e)); setStatus("Error"); }
  };

  useEffect(() => { void reload(); }, []);

  const apply = async () => {
    if (!recipe) return;
    setBusy(true); setError(null); setStatus("Aplicando cambios...");
    try { await applyRecipe(recipe); setStatus("Cambios aplicados ✓"); }
    catch (e) { setError(e instanceof Error ? e.message : String(e)); setStatus("Error"); }
    finally { setBusy(false); }
  };

  return <div style={{ padding: 16 }}>
    <Rows spacing="2u">
      <Title size="small">ChatGPT Canva Editor</Title>
      <Text>{status}</Text>
      {recipe && <Alert tone="info">{recipe.name} · {recipe.operations.length} operación(es)</Alert>}
      {error && <Alert tone="critical">{error}</Alert>}
      <Button variant="secondary" onClick={reload} disabled={busy}>Recargar receta</Button>
      <Button variant="primary" onClick={apply} disabled={busy || !recipe || recipe.operations.length === 0} loading={busy}>Aplicar receta</Button>
      <Text>La app solo cambia el diseño cuando presionas “Aplicar receta”. Puedes usar Deshacer en Canva si no te gusta el resultado.</Text>
    </Rows>
  </div>;
}
