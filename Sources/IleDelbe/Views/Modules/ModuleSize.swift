/// How much room a module view gets. A style only places module views at one of these sizes.
enum ModuleSize: Equatable, Sendable {
    /// One ~70 pt row (Île pages).
    case compact
    /// A card in the grid (Grille, Île « Tout voir »).
    case card
    /// The 0.2 pane (Onglets).
    case full
}
