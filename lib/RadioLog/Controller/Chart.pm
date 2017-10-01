package RadioLog::Controller::Chart;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json encode_json);

# This action will render a template
sub home {
  my $self = shift;

  $self->stash(title => "Charts");
  $self->stash(subtitle => "Measure chart.");
  $self->stash(ws_url => $self->url_for('ws_datachart')->to_abs);


  my @ids = $self->rldata->address();
  my $row = $self->rldata->last(@ids);

  $self->render(id => [@ids], rowdata => $row);
}

sub show {
  my $self = shift;
  my $id = $self->req->param('addr');
  $self->stash(title => "Charts ID");
  $self->stash(subtitle => "Moduel Address ".$id);

  my $row = $self->rldata->find($id);
  $self->render();
}

my $clients = {};

sub data {
    my $self = shift;
    $self->app->log->debug(sprintf 'Client connected: %s:%s', $self->tx->remote_address,
              $self->tx->remote_port);

    # Save connect request.
    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = $self->tx;

    my $module_addr = 0;
    $self->on(message => sub {
        my ($self, $message) = @_;
        $self->app->log->debug(sprintf 'Data %s', $message);
        my $msg = decode_json($message);
        for (keys %{$msg}) {
          $self->app->log->debug(sprintf '%s -> %s', $_, $msg->{$_});
        }

        my @data_graph = ();
        foreach (@{$msg->{param}}) {
          $self->app->log->debug("Get Param: ".$_);
          push @data_graph, $self->rldata->graphdata($msg->{module_addr}, [$_]);
        }

        for my $cli (keys %$clients) {
          $clients->{$cli}->send({json => {
                data => [@data_graph],
                module_addr => $msg->{module_addr}
              }
          });
        }
    });

    $self->on(finish => sub {
        $self->app->log->debug('Client disconnected');
        delete $clients->{$id};
    });
}

1;
