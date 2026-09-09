/**
 * Event palette and rail toning mirror ColorPalette.swift and Color.toned().
 * EventRowStyle uses system labels on quiet surfaces; these previews use the
 * dark equivalents. Keep row geometry and fills in AppEventRow in sync with
 * EventRow and EventRowBackground.
 */

/** The eleven event colors, keyed the way `ColorPalette` names them. */
export const eventPalette = {
  lavender: "#7986cb",
  sage: "#33b679",
  grape: "#8e24aa",
  flamingo: "#e67c73",
  banana: "#f6bf26",
  tangerine: "#f4511e",
  peacock: "#039be5",
  graphite: "#616161",
  blueberry: "#3f51b5",
  basil: "#0b8043",
  tomato: "#d50000",
} as const;

/** `Constants.defaultCalendarColor` — what a calendar with no color falls to. */
export const defaultCalendarColor = "#4285f4";

const darkSurfaceSaturation = 0.55;
const darkSurfaceBrightness = 0.95;
const darkSurfaceBrightnessCeiling = 0.85;

/** Where the text flips from white to near-black, on WCAG relative luminance. */
const darkTextLuminance = 0.35;

/** The palette color as it is painted on the dark list. */
export function toned(hex: string): string {
  const [r, g, b] = components(hex);
  const [h, s, v] = toHsv(r, g, b);

  return toHex(
    toRgb(
      h,
      s * darkSurfaceSaturation,
      Math.min(v * darkSurfaceBrightness, darkSurfaceBrightnessCeiling),
    ),
  );
}

/** Black or white — whichever stays legible drawn on `hex`. */
export function readable(hex: string): string {
  const [r, g, b] = components(hex);
  const luminance =
    0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);

  return luminance > darkTextLuminance ? "#1c1c1c" : "#ffffff";
}

/**
 * Space-separated channels, so a color can be reused at several opacities with
 * `rgb(var(--x) / 0.5)` the way the app reuses one `Color` with `.opacity()`.
 */
export function channels(hex: string): string {
  return components(hex)
    .map((channel) => Math.round(channel * 255))
    .join(" ");
}

function components(hex: string): [number, number, number] {
  const value = hex.replace("#", "");
  if (value.length !== 6) {
    // `Color(hex:)` falls back to Google blue on anything it cannot read.
    return components(defaultCalendarColor);
  }

  const int = parseInt(value, 16);
  return [
    ((int >> 16) & 0xff) / 255,
    ((int >> 8) & 0xff) / 255,
    (int & 0xff) / 255,
  ];
}

function toHsv(r: number, g: number, b: number): [number, number, number] {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;

  let hue = 0;
  if (delta !== 0) {
    if (max === r) hue = ((g - b) / delta) % 6;
    else if (max === g) hue = (b - r) / delta + 2;
    else hue = (r - g) / delta + 4;

    hue /= 6;
    if (hue < 0) hue += 1;
  }

  return [hue, max === 0 ? 0 : delta / max, max];
}

function toRgb(h: number, s: number, v: number): [number, number, number] {
  const sector = Math.floor(h * 6);
  const offset = h * 6 - sector;
  const p = v * (1 - s);
  const q = v * (1 - offset * s);
  const t = v * (1 - (1 - offset) * s);

  switch (sector % 6) {
    case 0:
      return [v, t, p];
    case 1:
      return [q, v, p];
    case 2:
      return [p, v, t];
    case 3:
      return [p, q, v];
    case 4:
      return [t, p, v];
    default:
      return [v, p, q];
  }
}

function toHex([r, g, b]: [number, number, number]): string {
  return (
    "#" +
    [r, g, b]
      .map((channel) =>
        Math.round(channel * 255)
          .toString(16)
          .padStart(2, "0"),
      )
      .join("")
  );
}

/** Undoes the sRGB transfer function, which WCAG's luminance is defined on. */
function linear(channel: number): number {
  return channel <= 0.03928
    ? channel / 12.92
    : Math.pow((channel + 0.055) / 1.055, 2.4);
}

/**
 * How the row is painted. The three are exclusive and cover every row, as in
 * `EventRowStyle.Treatment`.
 */
export type RowTreatment =
  /** A meeting in progress: a subtle tint and stronger title. */
  | "ongoing"
  /** Declined, cancelled, or unanswered — outlined rather than filled. */
  | "bordered"
  /** The default: a neutral surface with a calendar-color rail. */
  | "filled";

export interface RowStyleInput {
  /** The event's color, untoned — a palette value as Google reports it. */
  color?: string;
  treatment?: RowTreatment;
  /** Tentative rows get diagonal stripes over their fill. */
  tentative?: boolean;
  /** Declined and cancelled events are struck through. */
  struckThrough?: boolean;
  /** A past event is faded whole, content and fill together. */
  past?: boolean;
}

export interface RowStyle {
  treatment: RowTreatment;
  /** Toned channels, for `rgb(… / a)`. */
  tint: string;
  title: string;
  titleWeight: number;
  detail: string;
  isStriped: boolean;
  isStruckThrough: boolean;
  /** Location and meeting link, which a past event no longer needs. */
  showsAccessories: boolean;
  contentOpacity: number;
}

/** Every visual decision a row makes, resolved as `EventRowStyle` resolves it. */
export function rowStyle({
  color = defaultCalendarColor,
  treatment = "filled",
  tentative = false,
  struckThrough = false,
  past = false,
}: RowStyleInput): RowStyle {
  // The rail keeps the same toned calendar color as the native app.
  const tintHex = toned(color);
  const tint = channels(tintHex);

  return {
    treatment,
    tint,
    title: "#f2f2f2",
    titleWeight: treatment === "ongoing" ? 500 : 400,
    detail: "#ababab",
    isStriped: tentative && treatment === "filled",
    isStruckThrough: struckThrough,
    showsAccessories: !past,
    contentOpacity: past ? 0.4 : 1,
  };
}
