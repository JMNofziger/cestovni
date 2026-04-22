# Add Vehicle CTA Pill

A small, persistent call-to-action that lives in the **app header**, on the right end of the **Vehicle** strip. It is the primary entry point for getting a brand-new user from a blank slate to a usable app state.

## When it appears

- **Visible** whenever the store contains zero vehicles (`vehicles.length === 0`).
- **Replaced** by a `<Select>` dropdown of vehicles as soon as one or more vehicles exist. The CTA is mutually exclusive with the vehicle picker — never both.
- Renders identically across every route (Log, History, Metrics, Maintenance) because it lives in the shared `AppHeader` component.

## Visual spec

- Shape: a compact **pill** with the same rounded-md radius as other ledger controls (`0.375rem`).
- Fill: solid **ink** (near-black in light mode, cream-ink in dark mode).
- Text: **paper** color, all-caps, mono, tracked wider — `font-mono uppercase tracking-wider text-xs`.
- Icon: a **lucide `Plus`** glyph, `h-3 w-3`, sitting tight against the label with a `gap-1`.
- Border: `1px solid ink` on all sides (matches the inverted pill family used for active toggle states).
- Padding: `px-2.5 py-1`. Sits inline with the **VEHICLE** label and a hairline rule that fills the space between them.

## Behavior

- Renders as a `<Link to="/settings">` — clicking it performs a client-side TanStack route change to the **Settings** view.
- On Settings, the user lands directly above the **Vehicles** card where an **Add** button opens the vehicle dialog (name, make/model, year, fuel type, starting odometer, color swatch).
- After the first vehicle is added, the store auto-selects it as both `selectedVehicleId` and `defaultVehicleId`. On the next render of the header, the CTA disappears and the vehicle `<Select>` takes its slot.

## Empty-state pairing

The CTA in the header is reinforced by the **`EmptyVehiclesPrompt`** card rendered in the body of every data view (Log, History, Metrics, Maintenance) when no vehicles exist. That card carries the same destination — a larger `GO TO SETTINGS` button — so users have two redundant paths to the same place. The header pill is the persistent, lightweight reminder; the body card is the louder one-time invitation.

## Accessibility

- The link inherits its accessible name from the visible **"Add vehicle"** label — no extra `aria-label` needed.
- `Plus` icon is decorative and is not announced separately.
- Inverted ink-on-paper contrast comfortably exceeds WCAG AA in both themes.
