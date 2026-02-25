import UIKit

class HexViewerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    // MARK: - UI Elements
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.register(HexViewerCell.self, forCellReuseIdentifier: "HexViewerCell")
        table.separatorStyle = .singleLine
        table.backgroundColor = Constants.Colors.primaryBackground
        table.allowsSelection = true
        return table
    }()
    
    private lazy var searchBar: UISearchBar = {
        let search = UISearchBar()
        search.translatesAutoresizingMaskIntoConstraints = false
        search.placeholder = "Search address (0x...)"
        search.delegate = self
        search.searchBarStyle = .minimal
        return search
    }()
    
    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Filters", for: .normal)
        button.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        button.addTarget(self, action: #selector(showFilters), for: .touchUpInside)
        return button
    }()
    
    private lazy var goToButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Go To", for: .normal)
        button.setImage(UIImage(systemName: "arrow.right.circle"), for: .normal)
        button.addTarget(self, action: #selector(showGoToMenu), for: .touchUpInside)
        return button
    }()
    
    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private lazy var annotationToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isOn = true
        toggle.addTarget(self, action: #selector(toggleAnnotations), for: .valueChanged)
        return toggle
    }()
    
    private lazy var annotationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Annotations"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .label
        return label
    }()
    
    // MARK: - Properties
    
    private let fileURL: URL
    private var initialFileData: Data?
    private var binaryData: Data?
    private let bytesPerRow = 16
    private var showAnnotations = true
    private var filteredRanges: [Range<Int>] = []
    private var displayedByteCount: Int = 0
    private var highlightedFileOffset: Int?
    private var highlightedRow: Int?
    private lazy var baseLoadAddress: UInt64 = computeBaseLoadAddress()
    
    // Filter state
    private var activeFilters: Set<HexViewerFilter> = []
    private var visibleSections: Set<String> = []
    
    // Analysis data
    private let segments: [SegmentModel]
    private let sections: [SectionModel]
    private let functions: [FunctionModel]
    private let symbols: [SymbolModel]
    
    // MARK: - Initialization
    
    init(fileURL: URL, fileData: Data? = nil, segments: [SegmentModel], sections: [SectionModel], functions: [FunctionModel], symbols: [SymbolModel]) {
        self.fileURL = fileURL
        self.initialFileData = fileData
        self.segments = segments
        self.sections = sections
        self.functions = functions
        self.symbols = symbols
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Hex Viewer"
        view.backgroundColor = Constants.Colors.primaryBackground
        
        setupUI()
        setupNavigationBar()
        loadBinaryData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        let toolbar = UIStackView(arrangedSubviews: [filterButton, goToButton])
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.axis = .horizontal
        toolbar.spacing = Constants.UI.standardSpacing
        toolbar.distribution = .fillEqually
        
        let annotationStack = UIStackView(arrangedSubviews: [annotationLabel, annotationToggle])
        annotationStack.translatesAutoresizingMaskIntoConstraints = false
        annotationStack.axis = .horizontal
        annotationStack.spacing = Constants.UI.compactSpacing
        
        view.addSubview(searchBar)
        view.addSubview(toolbar)
        view.addSubview(annotationStack)
        view.addSubview(tableView)
        view.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            toolbar.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: Constants.UI.compactSpacing),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.UI.standardSpacing),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.UI.standardSpacing),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            
            annotationStack.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: Constants.UI.compactSpacing),
            annotationStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tableView.topAnchor.constraint(equalTo: annotationStack.bottomAnchor, constant: Constants.UI.compactSpacing),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor),
            
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.UI.standardSpacing),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.UI.standardSpacing),
            infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.UI.compactSpacing),
            infoLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        updateInfoLabel()
    }
    
    private func setupNavigationBar() {
        let exportButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportHexDump)
        )
        
        let legendButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showLegend)
        )
        
        navigationItem.rightBarButtonItems = [exportButton, legendButton]
    }
    
    // MARK: - Data Loading
    
    private func loadBinaryData() {
        do {
            // Check file size before loading
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                // Warn if file is larger than 100MB
                if fileSize > 100 * 1024 * 1024 {
                    showLargeFileWarning(fileSize: fileSize) { [weak self] shouldContinue in
                        if shouldContinue {
                            self?.performDataLoad()
                        }
                    }
                    return
                }
            }
            
            performDataLoad()
        } catch {
            showAlert(title: "Error", message: "Failed to load binary data: \(error.localizedDescription)")
        }
    }
    
    private func performDataLoad() {
        do {
            // If an initial in-memory data blob is provided (cached during decompile), use it
            if let cached = initialFileData {
                binaryData = cached
            } else {
                binaryData = try Data(contentsOf: fileURL)
            }
            resetFilteredRanges()
            updateInfoLabel()
            tableView.reloadData()
        } catch {
            showAlert(title: "Error", message: "Failed to load binary data: \(error.localizedDescription)")
        }
    }
    
    private func showLargeFileWarning(fileSize: Int64, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Large File Warning",
            message: "This file is \(Constants.formatBytes(fileSize)). Loading large files may cause memory issues. Continue?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        
        alert.addAction(UIAlertAction(title: "Load Anyway", style: .destructive) { _ in
            completion(true)
        })
        
        present(alert, animated: true)
    }
    
    private func updateInfoLabel() {
        guard let data = binaryData else {
            infoLabel.text = "No data loaded"
            return
        }
        let totalBytes = data.count
        let visibleBytes = displayedByteCount
        let filterLabel = activeFilters.isEmpty ? "All" : activeFilters.map { $0.displayName }.sorted().joined(separator: ", ")
        let sectionLabel = (activeFilters.isEmpty || visibleSections.isEmpty) ? "Sections: All" : "Sections: \(visibleSections.count)"
        infoLabel.text = "Total: \(Constants.formatBytes(Int64(totalBytes))) | Visible: \(Constants.formatBytes(Int64(visibleBytes))) | Filter: \(filterLabel) | \(sectionLabel) | Base: \(Constants.formatAddress(baseLoadAddress))"
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard binaryData != nil, displayedByteCount > 0 else { return 0 }
        return (displayedByteCount + bytesPerRow - 1) / bytesPerRow
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HexViewerCell", for: indexPath) as? HexViewerCell else {
            return UITableViewCell()
        }
        
        guard let rowContext = contextForRow(indexPath.row) else { return cell }
        let isHighlighted: Bool
        if let highlightOffset = highlightedFileOffset {
            isHighlighted = highlightOffset >= rowContext.fileOffset && highlightOffset < rowContext.fileOffset + rowContext.data.count
        } else {
            isHighlighted = false
        }
        cell.configure(with: rowContext.data, address: rowContext.address,
                   isHighlighted: isHighlighted, annotationText: annotationText(for: rowContext.section))
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let rowContext = contextForRow(indexPath.row) else { return }
        showAddressDetails(address: rowContext.address, offset: rowContext.fileOffset)
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let rowContext = contextForRow(indexPath.row) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let copyAddress = UIAction(title: "Copy Address", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = Constants.formatAddress(rowContext.address)
            }
            let copyBytes = UIAction(title: "Copy Hex Bytes", image: UIImage(systemName: "rectangle.on.rectangle")) { _ in
                let hexString = rowContext.data.map { String(format: "%02X", $0) }.joined(separator: " ")
                UIPasteboard.general.string = hexString
            }
            let showDetails = UIAction(title: "Show Details", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                self?.showAddressDetails(address: rowContext.address, offset: rowContext.fileOffset)
            }
            return UIMenu(children: [copyAddress, copyBytes, showDetails])
        }
    }
    
    // MARK: - Annotation Control
    
    @objc private func toggleAnnotations() {
        showAnnotations = annotationToggle.isOn
        tableView.reloadData()
    }
    
    // MARK: - Helper Methods
    
    private struct HexRowContext {
        let data: Data
        let fileOffset: Int
        let address: UInt64
        let section: SectionModel?
    }
    
    private func computeBaseLoadAddress() -> UInt64 {
        let candidates = sections.compactMap { section -> UInt64? in
            let offset = UInt64(section.offset)
            guard section.address >= offset else { return nil }
            return section.address - offset
        }
        return candidates.min() ?? 0
    }
    
    private func resetFilteredRanges() {
        guard let data = binaryData else {
            filteredRanges = []
            displayedByteCount = 0
            visibleSections.removeAll()
            return
        }
        filteredRanges = [0..<data.count]
        displayedByteCount = data.count
        visibleSections.removeAll()
    }
    
    private func totalFilteredBytes() -> Int {
        return filteredRanges.reduce(0) { $0 + $1.count }
    }
    
    private func rangeContext(forByteIndex index: Int) -> (rangeIndex: Int, offset: Int)? {
        guard index >= 0 else { return nil }
        var remaining = index
        for (idx, range) in filteredRanges.enumerated() {
            if remaining < range.count {
                return (idx, remaining)
            }
            remaining -= range.count
        }
        return nil
    }
    
    private func contextForRow(_ row: Int) -> HexRowContext? {
        guard let dataBlob = binaryData, !filteredRanges.isEmpty else { return nil }
        let startByteIndex = row * bytesPerRow
        guard startByteIndex < displayedByteCount else { return nil }
        guard let baseContext = rangeContext(forByteIndex: startByteIndex) else { return nil }
        var rangeIndex = baseContext.rangeIndex
        var offsetInRange = baseContext.offset
        var remaining = bytesPerRow
        var collected = Data()
        var firstFileOffset: Int?
        while remaining > 0 && rangeIndex < filteredRanges.count {
            let range = filteredRanges[rangeIndex]
            let available = range.count - offsetInRange
            if available <= 0 {
                rangeIndex += 1
                offsetInRange = 0
                continue
            }
            let chunkSize = min(remaining, available)
            let chunkStart = range.lowerBound + offsetInRange
            let chunkEnd = min(chunkStart + chunkSize, dataBlob.count)
            if chunkStart >= chunkEnd { break }
            collected.append(dataBlob[chunkStart..<chunkEnd])
            if firstFileOffset == nil {
                firstFileOffset = chunkStart
            }
            remaining -= chunkSize
            offsetInRange += chunkSize
            if offsetInRange >= range.count {
                rangeIndex += 1
                offsetInRange = 0
            }
        }
        guard let fileOffset = firstFileOffset else { return nil }
        let address = virtualAddress(forFileOffset: fileOffset)
        let section = findSection(for: address)
        return HexRowContext(data: collected, fileOffset: fileOffset, address: address, section: section)
    }
    
    private func virtualAddress(forFileOffset offset: Int) -> UInt64 {
        let absoluteOffset = UInt64(offset)
        if let section = sections.first(where: { absoluteOffset >= UInt64($0.offset) && absoluteOffset < UInt64($0.offset) + $0.size }) {
            let delta = absoluteOffset - UInt64(section.offset)
            return section.address + delta
        }
        return baseLoadAddress + absoluteOffset
    }
    
    private func fileOffset(forVirtualAddress address: UInt64) -> Int? {
        if let section = findSection(for: address) {
            let delta = address - section.address
            return Int(UInt64(section.offset) + delta)
        }
        guard let data = binaryData, address >= baseLoadAddress else { return nil }
        let candidate = address - baseLoadAddress
        return candidate < UInt64(data.count) ? Int(candidate) : nil
    }
    
    private func rowIndex(forFileOffset offset: Int) -> Int? {
        guard !filteredRanges.isEmpty else { return nil }
        var consumed = 0
        for range in filteredRanges {
            if offset >= range.lowerBound && offset < range.upperBound {
                let relative = consumed + (offset - range.lowerBound)
                return relative / bytesPerRow
            }
            consumed += range.count
        }
        return nil
    }
    
    private func annotationText(for section: SectionModel?) -> String? {
        guard showAnnotations, let section = section else { return nil }
        if let typeDescription = sectionTypeDescription(for: section) {
            return "\(section.segmentName).\(section.sectionName) (\(typeDescription))"
        }
        return "\(section.segmentName).\(section.sectionName)"
    }
    
    private func sectionTypeDescription(for section: SectionModel) -> String? {
        let lowercased = section.sectionName.lowercased()
        let segmentLower = section.segmentName.lowercased()
        if lowercased.contains("text") || lowercased.contains("code") || segmentLower.contains("text") {
            return "Code"
        }
        if lowercased.contains("data") || lowercased.contains("const") || lowercased.contains("bss") || segmentLower.contains("data") {
            return "Data"
        }
        if lowercased.contains("string") || lowercased.contains("cstring") {
            return "Strings"
        }
        return nil
    }
    
    private func sectionsMatchingActiveFilters() -> [SectionModel] {
        guard !activeFilters.isEmpty else { return sections }
        return sections.filter { section in
            activeFilters.contains { $0.matches(section: section) }
        }
    }
    
    private func dataForCurrentView() -> Data? {
        guard let data = binaryData, !filteredRanges.isEmpty else { return nil }
        if filteredRanges.count == 1,
           filteredRanges.first?.lowerBound == 0,
           filteredRanges.first?.upperBound == data.count {
            return data
        }
        var buffer = Data(capacity: displayedByteCount)
        for range in filteredRanges {
            let lower = max(0, min(range.lowerBound, data.count))
            let upper = max(0, min(range.upperBound, data.count))
            if lower < upper {
                buffer.append(data[lower..<upper])
            }
        }
        return buffer
    }
    
    private func promptToClearFilters(for address: UInt64) {
        let message = "Address \(Constants.formatAddress(address)) is hidden by the active filters. Show all sections?"
        let alert = UIAlertController(title: "Address Not Visible", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Show All", style: .default) { [weak self] _ in
            self?.clearFilters()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.scrollToAddress(address)
            }
        })
        present(alert, animated: true)
    }
    
    private func findSection(for address: UInt64) -> SectionModel? {
        return sections.first { section in
            address >= section.address && address < section.address + section.size
        }
    }
    
    private func findFunction(for address: UInt64) -> FunctionModel? {
        return functions.first { function in
            address >= function.startAddress && address <= function.endAddress
        }
    }
    
    private func findSymbol(for address: UInt64) -> SymbolModel? {
        return symbols.first { symbol in
            symbol.address == address
        }
    }
    
    private func showAddressDetails(address: UInt64, offset: Int) {
        var details = "Address: \(Constants.formatAddress(address))\n"
        details += "File Offset: 0x\(String(format: "%08X", offset))\n\n"
        
        if let section = findSection(for: address) {
            details += "Section: \(section.segmentName).\(section.sectionName)\n"
            if let typeDescription = sectionTypeDescription(for: section) {
                details += "Type: \(typeDescription)\n"
            }
        }
        
        if let function = findFunction(for: address) {
            details += "Function: \(function.name)\n"
            details += "Function Range: \(Constants.formatAddress(function.startAddress)) - \(Constants.formatAddress(function.endAddress))\n"
        }
        
        if let symbol = findSymbol(for: address) {
            details += "Symbol: \(symbol.name)\n"
            details += "Type: \(symbol.type)\n"
        }
        
        let alert = UIAlertController(title: "Address Details", message: details, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.addAction(UIAlertAction(title: "Copy Address", style: .default) { _ in
            UIPasteboard.general.string = Constants.formatAddress(address)
        })
        present(alert, animated: true)
    }
    
    @objc private func showLegend() {
        let legend = """
        Hex Viewer Legend
        
        📍 Address Column: Memory address in hexadecimal
        🔢 Hex Column: Raw byte values in hex
        📝 ASCII Column: Printable characters (. for non-printable)
        
        Annotations:
        • Section names show which section contains the data
        • Highlighted rows indicate current selection
        • Use "Go To" to navigate by address, function, or section
        
        Filters:
        • Show Code Sections: Display only executable code
        • Show Data Sections: Display only data sections
        
        Tips:
        • Long-press on a row for context menu
        • Use the search bar to jump to specific addresses
        • Export hex dump to text or binary format
        """
        
        let alert = UIAlertController(title: "Hex Viewer Help", message: legend, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Navigation Actions
    
    @objc private func showGoToMenu() {
        let alert = UIAlertController(title: "Go To", message: "Select navigation option", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Go to Address", style: .default) { [weak self] _ in
            self?.showGoToAddress()
        })
        
        alert.addAction(UIAlertAction(title: "Go to Function", style: .default) { [weak self] _ in
            self?.showGoToFunction()
        })
        
        alert.addAction(UIAlertAction(title: "Go to Section", style: .default) { [weak self] _ in
            self?.showGoToSection()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = goToButton
        }
        
        present(alert, animated: true)
    }
    
    private func showGoToAddress() {
        let alert = UIAlertController(title: "Go to Address", message: "Enter hexadecimal address (e.g., 0x1000)", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "0x..."
            textField.keyboardType = .asciiCapable
        }
        
        alert.addAction(UIAlertAction(title: "Go", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let text = alert?.textFields?.first?.text else { return }
            
            if let address = self.parseAddress(text) {
                self.scrollToAddress(address)
            } else {
                self.showAlert(title: "Invalid Address", message: "Please enter a valid hexadecimal address (e.g., 0x1000)")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showGoToFunction() {
        let functionNames = functions.map { $0.name }
        
        if functionNames.isEmpty {
            showAlert(title: "No Functions", message: "No functions found in this binary")
            return
        }
        
        let functionPickerVC = FunctionPickerViewController(functions: functions) { [weak self] selectedFunction in
            self?.scrollToAddress(selectedFunction.startAddress)
        }
        
        let navController = UINavigationController(rootViewController: functionPickerVC)
        present(navController, animated: true)
    }
    
    private func showGoToSection() {
        let alert = UIAlertController(title: "Go to Section", message: "Select a section", preferredStyle: .actionSheet)
        
        for section in sections {
            let title = "\(section.segmentName).\(section.sectionName) (\(Constants.formatAddress(section.address)))"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.scrollToAddress(section.address)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = goToButton
        }
        
        present(alert, animated: true)
    }
    
    private func parseAddress(_ text: String) -> UInt64? {
        var cleanText = text.trimmingCharacters(in: .whitespaces)
        
        if cleanText.hasPrefix("0x") || cleanText.hasPrefix("0X") {
            cleanText = String(cleanText.dropFirst(2))
        }
        
        return UInt64(cleanText, radix: 16)
    }
    
    func scrollToAddress(_ address: UInt64) {
        guard binaryData != nil else { return }
        guard let fileOffset = fileOffset(forVirtualAddress: address) else {
            showAlert(title: "Address Out of Range", message: "No section contains \(Constants.formatAddress(address))")
            return
        }
        guard let row = rowIndex(forFileOffset: fileOffset) else {
            if activeFilters.isEmpty {
                showAlert(title: "Address Not Visible", message: "The computed file offset is outside the current view")
            } else {
                promptToClearFilters(for: address)
            }
            return
        }
        let indexPath = IndexPath(row: row, section: 0)
        tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        let previousRow = highlightedRow
        highlightedFileOffset = fileOffset
        highlightedRow = row
        var reloadPaths: [IndexPath] = [indexPath]
        if let previousRow = previousRow, previousRow != row {
            reloadPaths.append(IndexPath(row: previousRow, section: 0))
        }
        tableView.reloadRows(at: reloadPaths, with: .none)
        showJumpToast(for: address)
    }
    
    private func showJumpToast(for address: UInt64) {
        let message = "Jumped to \(Constants.formatAddress(address))"
        showBanner(message: message, backgroundColor: Constants.Colors.successColor.withAlphaComponent(0.9), delay: 0.3)
    }

    private func showFilterToast(sectionCount: Int) {
        let pluralized = sectionCount == 1 ? "section" : "sections"
        let message = "Filter applied: \(sectionCount) \(pluralized)"
        showBanner(message: message, backgroundColor: Constants.Colors.accentColor.withAlphaComponent(0.9), delay: 0.0)
    }
    
    private func showBanner(message: String, backgroundColor: UIColor, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let toast = UILabel()
            toast.text = message
            toast.backgroundColor = backgroundColor
            toast.textColor = .white
            toast.textAlignment = .center
            toast.font = .systemFont(ofSize: 14, weight: .medium)
            toast.frame = CGRect(x: 20, y: self.view.safeAreaInsets.top + 60,
                                 width: self.view.bounds.width - 40, height: 44)
            toast.layer.cornerRadius = 8
            toast.clipsToBounds = true
            self.view.addSubview(toast)
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut) {
                toast.alpha = 0
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Filter Actions
    
    @objc private func showFilters() {
        let alert = UIAlertController(title: "Hex Viewer Filters", message: "Select data to display", preferredStyle: .actionSheet)
        
        // Filter by data type
        alert.addAction(UIAlertAction(title: "Show Code Sections", style: .default) { [weak self] _ in
            self?.filterByType(.code)
        })
        
        alert.addAction(UIAlertAction(title: "Show Data Sections", style: .default) { [weak self] _ in
            self?.filterByType(.data)
        })
        
        alert.addAction(UIAlertAction(title: "Show String Sections", style: .default) { [weak self] _ in
            self?.filterByType(.strings)
        })
        
        alert.addAction(UIAlertAction(title: "Show All", style: .default) { [weak self] _ in
            self?.clearFilters()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterButton
        }
        
        present(alert, animated: true)
    }
    
    private func filterByType(_ filterType: HexViewerFilter) {
        activeFilters.removeAll()
        activeFilters.insert(filterType)
        applyFilters()
    }
    
    private func clearFilters() {
        activeFilters.removeAll()
        resetFilteredRanges()
        highlightedFileOffset = nil
        highlightedRow = nil
        tableView.reloadData()
        updateInfoLabel()
    }
    
    private func applyFilters() {
        guard let data = binaryData else { return }
        
        if activeFilters.isEmpty {
            resetFilteredRanges()
            tableView.reloadData()
            updateInfoLabel()
            return
        }
        
        let filteredSections = sectionsMatchingActiveFilters()
        guard !filteredSections.isEmpty else {
            showAlert(title: "No Sections Matched", message: "The current filter has no matching sections. Showing all data instead.")
            clearFilters()
            return
        }
        let sortedSections = filteredSections.sorted { lhs, rhs in
            return lhs.offset < rhs.offset
        }
        filteredRanges = sortedSections.compactMap { section in
            let lower = Int(section.offset)
            let upper = min(lower + Int(section.size), data.count)
            return lower < upper ? lower..<upper : nil
        }
        displayedByteCount = totalFilteredBytes()
        if displayedByteCount == 0 {
            showAlert(title: "Empty Selection", message: "No bytes available for the selected filter.")
            clearFilters()
            return
        }
        visibleSections = Set(sortedSections.map { "\($0.segmentName).\($0.sectionName)" })
        highlightedFileOffset = nil
        highlightedRow = nil
        tableView.reloadData()
        updateInfoLabel()
        showFilterToast(sectionCount: filteredSections.count)
    }
    
    // MARK: - Export
    
    @objc private func exportHexDump() {
        guard binaryData != nil, displayedByteCount > 0 else { return }
        
        let alert = UIAlertController(title: "Export Hex Dump", message: "Choose export format", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Text Format", style: .default) { [weak self] _ in
            self?.performExport(format: .text)
        })
        
        alert.addAction(UIAlertAction(title: "Binary Format", style: .default) { [weak self] _ in
            self?.performExport(format: .binary)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func performExport(format: HexExportFormat) {
        let exportData: Data
        let filename: String
        switch format {
        case .text:
            let hexDump = generateHexDump()
            guard !hexDump.isEmpty else {
                showAlert(title: "Export Failed", message: "Nothing to export for the current view")
                return
            }
            exportData = Data(hexDump.utf8)
            filename = "hexdump.txt"
        case .binary:
            guard let payload = dataForCurrentView(), !payload.isEmpty else {
                showAlert(title: "Export Failed", message: "No bytes available for binary export")
                return
            }
            exportData = payload
            filename = "binary.bin"
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try exportData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let popover = activityVC.popoverPresentationController {
                popover.barButtonItem = navigationItem.rightBarButtonItem
            }
            
            present(activityVC, animated: true)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }
    
    private func generateHexDump() -> String {
        guard displayedByteCount > 0 else { return "" }
        var dump = ""
        let rowCount = (displayedByteCount + bytesPerRow - 1) / bytesPerRow
        for row in 0..<rowCount {
            guard let context = contextForRow(row) else { continue }
            let rowData = context.data
            dump += String(format: "%016llX  ", context.address)
            for byte in rowData {
                dump += String(format: "%02X ", byte)
            }
            for _ in rowData.count..<bytesPerRow {
                dump += "   "
            }
            dump += " |"
            for byte in rowData {
                if byte >= 32 && byte < 127 {
                    dump += String(UnicodeScalar(byte))
                } else {
                    dump += "."
                }
            }
            dump += "|\n"
        }
        return dump
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        guard let text = searchBar.text, !text.isEmpty else { return }
        
        if let address = parseAddress(text) {
            scrollToAddress(address)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
    }
    
    // MARK: - Alerts
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Hex Viewer Cell

class HexViewerCell: UITableViewCell {
    
    private let addressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = Constants.Colors.addressColor
        return label
    }()
    
    private let hexLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()
    
    private let asciiLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let sectionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 9, weight: .regular)
        label.textColor = Constants.Colors.accentColor
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(addressLabel)
        contentView.addSubview(hexLabel)
        contentView.addSubview(asciiLabel)
        contentView.addSubview(sectionLabel)
        
        NSLayoutConstraint.activate([
            addressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            addressLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            addressLabel.widthAnchor.constraint(equalToConstant: 140),
            
            hexLabel.leadingAnchor.constraint(equalTo: addressLabel.trailingAnchor, constant: 8),
            hexLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            hexLabel.trailingAnchor.constraint(equalTo: asciiLabel.leadingAnchor, constant: -8),
            
            asciiLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            asciiLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            asciiLabel.widthAnchor.constraint(equalToConstant: 140),
            
            sectionLabel.leadingAnchor.constraint(equalTo: addressLabel.leadingAnchor),
            sectionLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 2),
            sectionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    func configure(with data: Data, address: UInt64, isHighlighted: Bool, annotationText: String?) {
        // Address
        addressLabel.text = String(format: "%016llX", address)
        
        // Hex bytes
        var hexString = ""
        for (index, byte) in data.enumerated() {
            hexString += String(format: "%02X", byte)
            if (index + 1) % 4 == 0 && index < data.count - 1 {
                hexString += " "
            } else if index < data.count - 1 {
                hexString += " "
            }
        }
        hexLabel.text = hexString
        
        // ASCII representation
        var asciiString = ""
        for byte in data {
            if byte >= 32 && byte < 127 {
                asciiString += String(UnicodeScalar(byte))
            } else {
                asciiString += "."
            }
        }
        asciiLabel.text = asciiString
        
        // Section annotation
        if let annotation = annotationText {
            sectionLabel.text = annotation
            sectionLabel.isHidden = false
        } else {
            sectionLabel.isHidden = true
        }
        
        // Highlight if needed
        if isHighlighted {
            contentView.backgroundColor = Constants.Colors.accentColor.withAlphaComponent(0.2)
        } else {
            contentView.backgroundColor = Constants.Colors.primaryBackground
        }
    }
}

// MARK: - Supporting Types

enum HexViewerFilter {
    case code
    case data
    case strings
}

enum HexExportFormat {
    case text
    case binary
}

private extension HexViewerFilter {
    var displayName: String {
        switch self {
        case .code:
            return "Code"
        case .data:
            return "Data"
        case .strings:
            return "Strings"
        }
    }
    
    func matches(section: SectionModel) -> Bool {
        let sectionName = section.sectionName.lowercased()
        let segmentName = section.segmentName.lowercased()
        switch self {
        case .code:
            return segmentName.contains("text") ||
                   sectionName.contains("text") ||
                   sectionName.contains("stub")
        case .data:
            return segmentName.contains("data") ||
                   sectionName.contains("data") ||
                   sectionName.contains("bss") ||
                   sectionName.contains("const")
        case .strings:
            return sectionName.contains("string") ||
                   sectionName.contains("cstring") ||
                   sectionName.contains("ustring")
        }
    }
}

// MARK: - Function Picker

class FunctionPickerViewController: UITableViewController, UISearchBarDelegate {
    
    private let functions: [FunctionModel]
    private var filteredFunctions: [FunctionModel]
    private let onSelect: (FunctionModel) -> Void
    
    private lazy var searchBar: UISearchBar = {
        let search = UISearchBar()
        search.placeholder = "Search functions..."
        search.delegate = self
        return search
    }()
    
    init(functions: [FunctionModel], onSelect: @escaping (FunctionModel) -> Void) {
        self.functions = functions
        self.filteredFunctions = functions
        self.onSelect = onSelect
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Select Function"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.tableHeaderView = searchBar
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }
    
    @objc private func cancel() {
        dismiss(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFunctions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = nil
        cell.detailTextLabel?.text = nil
        
        let function = filteredFunctions[indexPath.row]
        
        // Create a formatted string with function name and address
        let nameFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let addressFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        
        let nameText = "\(function.name)\n"
        let addressText = Constants.formatAddress(function.startAddress)
        
        let attributedString = NSMutableAttributedString()
        attributedString.append(NSAttributedString(string: nameText, attributes: [.font: nameFont]))
        attributedString.append(NSAttributedString(string: addressText, attributes: [
            .font: addressFont,
            .foregroundColor: UIColor.secondaryLabel
        ]))
        
        cell.textLabel?.attributedText = attributedString
        cell.textLabel?.numberOfLines = 0
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let function = filteredFunctions[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onSelect(function)
        }
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredFunctions = functions
        } else {
            filteredFunctions = functions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        filteredFunctions = functions
        tableView.reloadData()
    }
}
