import UIKit

class TypeReconstructionViewController: UIViewController {
    private let results: TypeReconstructionResultsObject
    private var displayedTypes: [TypeReconstructedTypeObject] = []

    private let statsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Constants.Colors.secondaryBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    private let totalTypesLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let averageConfidenceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = Constants.Colors.primaryBackground
        return table
    }()

    init(results: TypeReconstructionResultsObject) {
        self.results = results
        self.displayedTypes = results.types.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Type Reconstruction"
        view.backgroundColor = Constants.Colors.primaryBackground

        setupUI()
        setupTableView()
        updateStats()
    }

    private func setupUI() {
        view.addSubview(statsView)
        view.addSubview(tableView)

        let statsStackView = UIStackView(arrangedSubviews: [totalTypesLabel, averageConfidenceLabel])
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 8
        statsView.addSubview(statsStackView)

        NSLayoutConstraint.activate([
            statsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsView.heightAnchor.constraint(equalToConstant: 70),

            statsStackView.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 12),
            statsStackView.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 12),
            statsStackView.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -12),
            statsStackView.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -12),

            tableView.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func updateStats() {
        let totalTypes = displayedTypes.count
        let totalConfidence = displayedTypes.map { $0.confidence }.reduce(0, +)
        let averageConfidence = totalTypes > 0 ? totalConfidence / Double(totalTypes) : 0.0

        let totalAttr = NSMutableAttributedString()
        totalAttr.append(NSAttributedString(string: "\(totalTypes)\n", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .bold),
            .foregroundColor: Constants.Colors.accentColor
        ]))
        totalAttr.append(NSAttributedString(string: "Types", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]))
        totalTypesLabel.attributedText = totalAttr

        let confidenceAttr = NSMutableAttributedString()
        confidenceAttr.append(NSAttributedString(string: String(format: "%.2f\n", averageConfidence), attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.systemGreen
        ]))
        confidenceAttr.append(NSAttributedString(string: "Avg Confidence", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]))
        averageConfidenceLabel.attributedText = confidenceAttr
    }
}

extension TypeReconstructionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TypeCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TypeCell")
        let type = displayedTypes[indexPath.row]
        cell.textLabel?.text = type.name
        cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cell.detailTextLabel?.text = "\(type.category) • size \(type.size) • conf \(String(format: "%.2f", type.confidence))"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.accessoryType = .none
        cell.backgroundColor = Constants.Colors.primaryBackground
        return cell
    }
}

extension TypeReconstructionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
