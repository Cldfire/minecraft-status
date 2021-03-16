use crate::get_server_status_rust;
use expect_test::{expect, Expect};
use tempfile::tempdir;

fn check(server_address: &str, app_group_container: Option<&str>, expect: Expect) {
    let dir = tempdir().unwrap();

    let app_group_container = app_group_container.unwrap_or_else(|| dir.path().to_str().unwrap());

    let result = get_server_status_rust(server_address, app_group_container)
        // Use display impl since most of the debug values are unstable
        .map(|status| status.to_string());
    expect.assert_debug_eq(&result);
}

#[test]
fn blank_server_address() {
    check(
        "",
        None,
        expect![[r#"
        Err(
            "empty server address",
        )
    "#]],
    );
}

#[test]
fn blank_app_group_container_path() {
    check(
        "test",
        Some(""),
        expect![[r#"
        Err(
            "empty app group container path",
        )
    "#]],
    );
}

#[test]
fn ping_success_basic() {
    check(
        "test.server.basic",
        None,
        expect![[r#"
            Ok(
                "Online",
            )
        "#]],
    );
}

#[test]
fn ping_success_full() {
    check(
        "test.server.full",
        None,
        expect![[r#"
            Ok(
                "Online",
            )
        "#]],
    );
}

#[test]
fn ping_failure_dnslookupfails() {
    check(
        "test.server.dnslookupfails",
        None,
        expect![[r#"
            Err(
                DnsLookupFailed,
            )
        "#]],
    );
}

// TODO: tests around file handling, caching
// TODO: tests using the C api

#[test]
#[cfg(feature = "online")]
fn ping_hypixel() {
    check(
        "mc.hypixel.net",
        None,
        expect![[r#"
            Ok(
                "Online",
            )
        "#]],
    );
}

#[test]
#[cfg(feature = "online")]
fn ping_google_lol() {
    check(
        "google.com",
        None,
        expect![[r#"
            Err(
                IoError(
                    Custom {
                        kind: TimedOut,
                        error: "connection timed out",
                    },
                ),
            )
        "#]],
    );
}
