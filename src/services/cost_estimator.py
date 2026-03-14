import json
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CostEstimate:
    total_monthly: float
    total_annual: float
    currency: str
    resources: list
    summary: str


def _run_infracost(args: list[str]) -> dict:
    result = subprocess.run(
        ["infracost"] + args,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Infracost failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def estimate_infrastructure_cost(
    terraform_dir: str | Path,
    usage_file: str | Path | None = None,
) -> CostEstimate:
    """
    Run infracost breakdown against a Terraform directory and return
    a structured cost estimate.

    Args:
        terraform_dir: Path to the Terraform root module.
        usage_file: Optional path to an infracost-usage.yml file
                     for usage-based resource cost estimation.
    """
    terraform_dir = Path(terraform_dir)
    args = [
        "breakdown",
        "--path", str(terraform_dir),
        "--format", "json",
        "--no-color",
    ]

    if usage_file:
        args.extend(["--usage-file", str(usage_file)])

    data = _run_infracost(args)

    total_monthly = float(data.get("totalMonthlyCost") or 0)
    currency = data.get("currency", "USD")

    resources = []
    for project in data.get("projects", []):
        for resource in project.get("breakdown", {}).get("resources", []):
            monthly = float(resource.get("monthlyCost") or 0)
            if monthly > 0:
                resources.append({
                    "name": resource["name"],
                    "monthly_cost": monthly,
                    "hourly_cost": float(resource.get("hourlyCost") or 0),
                })

    resources.sort(key=lambda r: r["monthly_cost"], reverse=True)

    summary_lines = [f"Estimated monthly cost: ${total_monthly:,.2f} {currency}"]
    for r in resources[:10]:
        summary_lines.append(f"  {r['name']}: ${r['monthly_cost']:,.2f}/mo")

    return CostEstimate(
        total_monthly=total_monthly,
        total_annual=round(total_monthly * 12, 2),
        currency=currency,
        resources=resources,
        summary="\n".join(summary_lines),
    )


def estimate_cost_diff(
    terraform_dir: str | Path,
    baseline_json: str | Path,
    usage_file: str | Path | None = None,
) -> dict:
    """
    Compare current Terraform state against a baseline cost snapshot.
    Useful for showing cost impact of infrastructure changes.

    Args:
        terraform_dir: Path to the Terraform root module.
        baseline_json: Path to a previously saved infracost JSON output.
        usage_file: Optional path to an infracost-usage.yml file.
    """
    args = [
        "diff",
        "--path", str(terraform_dir),
        "--compare-to", str(baseline_json),
        "--format", "json",
        "--no-color",
    ]

    if usage_file:
        args.extend(["--usage-file", str(usage_file)])

    return _run_infracost(args)


def save_cost_baseline(
    terraform_dir: str | Path,
    output_path: str | Path,
    usage_file: str | Path | None = None,
) -> None:
    """
    Save a cost breakdown snapshot as JSON for later comparison with diff.
    """
    args = [
        "breakdown",
        "--path", str(terraform_dir),
        "--format", "json",
        "--no-color",
    ]

    if usage_file:
        args.extend(["--usage-file", str(usage_file)])

    data = _run_infracost(args)
    Path(output_path).write_text(json.dumps(data, indent=2))
