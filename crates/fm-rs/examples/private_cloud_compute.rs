//! Private Cloud Compute example for macOS/iOS 27 and later.
//!
//! This requires Apple's managed `com.apple.developer.private-cloud-compute`
//! entitlement and a provisioning profile that authorizes it. From the
//! repository, use `just example-pcc` to let Xcode build an app-like bundle,
//! automatically manage and embed the profile, sign it, and run the example.

use std::time::Duration;

use fm_rs::{Error, GenerationOptions, PrivateCloudComputeLanguageModel, ReasoningLevel, Session};

fn main() -> Result<(), Error> {
    let model = PrivateCloudComputeLanguageModel::new()?;
    model.ensure_available()?;

    let quota = model.quota_usage()?;
    if quota.is_limit_reached() {
        eprintln!(
            "PCC quota is exhausted (resets {:?}); fall back to SystemLanguageModel",
            quota.reset_date
        );
        return Ok(());
    }
    println!("PCC context window: {} tokens", model.context_size()?);

    let session = Session::with_instructions(
        &model,
        "Analyze the request carefully and explain the important tradeoffs.",
    )?;

    // Apple recommends starting with Moderate and only using Deep when the
    // added latency and context consumption are justified.
    let response = session.respond_with_reasoning_timeout(
        "When should an application use an on-device model instead of PCC?",
        &GenerationOptions::default(),
        ReasoningLevel::Moderate,
        Duration::from_mins(2),
    );

    match response {
        Ok(response) => println!("{}", response.content()),
        Err(Error::QuotaLimitReached(msg)) => {
            eprintln!("Quota exhausted mid-session: {msg}; fall back to SystemLanguageModel");
        }
        Err(Error::NetworkFailure(msg) | Error::ServiceUnavailable(msg)) => {
            eprintln!("PCC unreachable: {msg}; retry later or fall back to SystemLanguageModel");
        }
        Err(err) => return Err(err),
    }

    Ok(())
}
