use sqlx::{
    error::BoxDynError,
    migrate::{Migration, MigrationSource, MigrationType},
};
use std::{future::Future, pin::Pin};

#[derive(Debug)]
pub struct EmbeddedMigrations;

// Embed SQL without a procedural macro or a runtime dependency on the source checkout.
impl MigrationSource<'static> for EmbeddedMigrations {
    fn resolve(
        self,
    ) -> Pin<Box<dyn Future<Output = Result<Vec<Migration>, BoxDynError>> + Send + 'static>> {
        Box::pin(async {
            Ok(vec![Migration::new(
                1,
                "library".into(),
                MigrationType::Simple,
                include_str!("../../../migrations/sqlite/0001_library.sql").into(),
                false,
            )])
        })
    }
}
