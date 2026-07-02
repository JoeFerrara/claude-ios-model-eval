```swift
// Paste into a single .swift file in a new iOS App target.
// In Info.plist: remove "Main storyboard file base name" / UIMainStoryboardFile key.
// Minimum deployment target: iOS 15 (UIButton.Configuration, CellRegistration, CompositionalLayout).

import UIKit

// MARK: - Entry Point

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController(rootViewController: TodayViewController())
        nav.navigationBar.prefersLargeTitles = true
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: - Data Model

struct AppItem: Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let color: UIColor

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
}

enum Section: Int, CaseIterable {
    case featured, topCharts, categories

    var title: String {
        switch self {
        case .featured:   return "Today"
        case .topCharts:  return "Top Charts"
        case .categories: return "Categories"
        }
    }
}

// MARK: - Cells

final class FeaturedCell: UICollectionViewCell {

    private let cardView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.layer.masksToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let gradientLayer: CAGradientLayer = {
        let l = CAGradientLayer()
        l.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor]
        l.locations = [0.45, 1.0]
        return l
    }()

    private let eyebrowLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.85)
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 26, weight: .bold)
        l.textColor = .white
        l.numberOfLines = 2
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIColor.white.withAlphaComponent(0.75)
        l.numberOfLines = 2
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(cardView)
        cardView.layer.addSublayer(gradientLayer)

        let stack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = cardView.bounds
    }

    func configure(with item: AppItem) {
        cardView.backgroundColor = item.color
        eyebrowLabel.text = item.subtitle.uppercased()
        titleLabel.text = item.title
        subtitleLabel.text = "Available now on the App Store"
    }
}

// ─────────────────────────────────────────────────────────────

final class TopChartCell: UICollectionViewCell {

    private let iconView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.layer.masksToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .label
        l.textAlignment = .center
        l.numberOfLines = 2
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            iconView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.65),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: AppItem) {
        iconView.backgroundColor = item.color
        titleLabel.text = item.title
    }
}

// ─────────────────────────────────────────────────────────────

final class CategoryCell: UICollectionViewCell {

    private let iconView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        return l
    }()

    private let chevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        return iv
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconView, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(row)
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            separator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: AppItem) {
        iconView.backgroundColor = item.color
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
    }
}

// MARK: - Section Header

final class SectionHeaderView: UICollectionReusableView {

    static let elementKind = UICollectionView.elementKindSectionHeader

    var onSeeAllTapped: (() -> Void)?

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textColor = .label
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return l
    }()

    private let seeAllButton: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.title = "See All"
        cfg.baseForegroundColor = .systemBlue
        cfg.contentInsets = .zero
        let b = UIButton(configuration: cfg)
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [titleLabel, seeAllButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        seeAllButton.addTarget(self, action: #selector(didTapSeeAll), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func didTapSeeAll() { onSeeAllTapped?() }

    func configure(title: String, onSeeAll: (() -> Void)?) {
        titleLabel.text = title
        onSeeAllTapped = onSeeAll
    }
}

// MARK: - TodayViewController

final class TodayViewController: UIViewController {

    // MARK: Types

    private typealias DataSource = UICollectionViewDiffableDataSource<Section, AppItem>
    private typealias Snapshot   = NSDiffableDataSourceSnapshot<Section, AppItem>

    // MARK: Sample data

    private let featuredItems: [AppItem] = [
        AppItem(title: "Darkroom",        subtitle: "App of the Day", color: UIColor(red: 0.40, green: 0.20, blue: 0.70, alpha: 1)),
        AppItem(title: "Monument Valley", subtitle: "Game of the Day", color: UIColor(red: 0.15, green: 0.55, blue: 0.65, alpha: 1)),
        AppItem(title: "Headspace",       subtitle: "App of the Day", color: UIColor(red: 0.92, green: 0.42, blue: 0.22, alpha: 1)),
    ]

    private let topChartItems: [AppItem] = [
        AppItem(title: "Social+",    subtitle: "", color: .systemBlue),
        AppItem(title: "RunTracker", subtitle: "", color: .systemGreen),
        AppItem(title: "PixelCam",   subtitle: "", color: .systemPink),
        AppItem(title: "NoteFlow",   subtitle: "", color: .systemOrange),
        AppItem(title: "Budgeter",   subtitle: "", color: .systemIndigo),
        AppItem(title: "Sleepwell",  subtitle: "", color: .systemMint),
    ]

    private let categoryItems: [AppItem] = [
        AppItem(title: "Games",            subtitle: "Action, Adventure & more",  color: UIColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 1)),
        AppItem(title: "Photo & Video",    subtitle: "Cameras, Editors & more",   color: .systemOrange),
        AppItem(title: "Productivity",     subtitle: "Tasks, Notes & more",       color: .systemBlue),
        AppItem(title: "Health & Fitness", subtitle: "Workouts, Nutrition",       color: .systemGreen),
        AppItem(title: "Entertainment",    subtitle: "Streaming & more",          color: .systemPurple),
        AppItem(title: "Travel",           subtitle: "Maps, Hotels & more",       color: .systemTeal),
        AppItem(title: "Finance",          subtitle: "Banking & Budgeting",       color: UIColor(red: 0.18, green: 0.62, blue: 0.48, alpha: 1)),
    ]

    // MARK: Views

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .systemBackground
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private var dataSource: DataSource!

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Today"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemBackground

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        collectionView.delegate = self
        configureDataSource()
        applyInitialSnapshot()
    }

    // MARK: Compositional Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] index, env in
            guard let self, let section = Section(rawValue: index) else { return nil }
            switch section {
            case .featured:   return self.makeFeaturedSection()
            case .topCharts:  return self.makeTopChartsSection(env: env)
            case .categories: return self.makeCategoriesSection()
            }
        }
    }

    /// Full-width, paging cards — each card is 350 pt tall.
    /// Item content insets provide the visible card margins while group width stays
    /// fractionalWidth(1.0) so groupPaging snaps cleanly to one card per page.
    private func makeFeaturedSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )
        item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(350)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    /// Horizontally scrolling squares — three fit exactly in the visible viewport.
    private func makeTopChartsSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let sideInset: CGFloat = 16
        let spacing:   CGFloat = 8
        // 3 items + 2 inter-item gaps must equal the inset-adjusted container width.
        let side = (env.container.effectiveContentSize.width - 2 * sideInset - 2 * spacing) / 3

        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .absolute(side), heightDimension: .absolute(side)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: sideInset, bottom: 16, trailing: sideInset)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    /// Vertical list — each row is exactly 80 pt tall.
    private func makeCategoriesSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80))
        )

        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(80)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 32, trailing: 0)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    private func makeHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(52)),
            elementKind: SectionHeaderView.elementKind,
            alignment: .top
        )
    }

    // MARK: Diffable Data Source

    private func configureDataSource() {

        // ── Cell registrations (iOS 14+ API, no register/dequeue) ──────────────

        let featuredReg = UICollectionView.CellRegistration<FeaturedCell, AppItem> { cell, _, item in
            cell.configure(with: item)
        }

        let topChartReg = UICollectionView.CellRegistration<TopChartCell, AppItem> { cell, _, item in
            cell.configure(with: item)
        }

        let categoryReg = UICollectionView.CellRegistration<CategoryCell, AppItem> { cell, _, item in
            cell.configure(with: item)
        }

        // ── Supplementary registration ──────────────────────────────────────────

        let headerReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: SectionHeaderView.elementKind
        ) { [weak self] header, _, indexPath in
            guard let section = Section(rawValue: indexPath.section) else { return }
            header.configure(title: section.title) { [weak self] in
                self?.handleSeeAll(for: section)
            }
        }

        // ── Data source ─────────────────────────────────────────────────────────

        dataSource = DataSource(collectionView: collectionView) { cv, indexPath, item in
            guard let section = Section(rawValue: indexPath.section) else { return nil }
            switch section {
            case .featured:
                return cv.dequeueConfiguredReusableCell(using: featuredReg,  for: indexPath, item: item)
            case .topCharts:
                return cv.dequeueConfiguredReusableCell(using: topChartReg,  for: indexPath, item: item)
            case .categories:
                return cv.dequeueConfiguredReusableCell(using: categoryReg,  for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { cv, _, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    private func applyInitialSnapshot() {
        var snap = Snapshot()
        snap.appendSections(Section.allCases)
        snap.appendItems(featuredItems,  toSection: .featured)
        snap.appendItems(topChartItems,  toSection: .topCharts)
        snap.appendItems(categoryItems,  toSection: .categories)
        dataSource.apply(snap, animatingDifferences: false)
    }

    // MARK: Actions

    private func handleSeeAll(for section: Section) {
        let alert = UIAlertController(title: section.title,
                                      message: "\"See All\" tapped",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension TodayViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        let alert = UIAlertController(title: item.title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

---

**Key decisions and why:**

**Layout math for Top Charts**
Three items fill the viewport exactly using `side = (containerWidth − 2×sideInset − 2×spacing) / 3`. Each group is `absolute(side)` wide so the orthogonal scroll container sees 3.0 groups in the viewport with no fractional peek. `interGroupSpacing` drives the visible gaps — not item content insets — so the icon area is maximised.

**Featured paging without fractional-width tricks**
The group stays `fractionalWidth(1.0)` so `.groupPaging` has a clean page boundary equal to the full container width. The visual card margins (16 pt each side) come from `item.contentInsets`, which shrink the rendered cell without changing the paging unit.

**`onSeeAllTapped` closure on the header**
Because `SupplementaryRegistration`'s handler fires on every dequeue/reconfigure (not just creation), using `addTarget` directly would stack duplicate targets on reuse. Assigning a closure overwrites the previous value cleanly each pass.

**`@main` AppDelegate, no storyboard**
Before building: delete `Main.storyboard` from the target and remove `UIMainStoryboardFile` from `Info.plist`. The window is created programmatically so there's nothing else to configure.
